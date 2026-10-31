#include "Hud.h"

#include "UiEngine.h"
#include "Aid.h"
#include "Config.h"
#include "OrgasmEngine.h"
#include "StrategyDecision.h"
#include "WebUI.h"
#include "WebUI_Log.h"
#include "InjuryEngine.h"

#include <Windows.h>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <vector>
#include <nlohmann/json.hpp>

namespace Hud
{
    namespace
    {
        constexpr double kSpeedNarrateDelay = 1.5;

        struct KeyBinding
        {
            const char* control;
            const char* path;
            int defaultVk;
            bool miniGame;  // false = controls group
            const char* legacyPath = nullptr;  // older dashboard path, used while path still holds the default
        };

        // Dashboard hotkeys (VK), defaults on the numpad laid out like the HUD grid, plus PgUp / PgDn
        // (pos_up / pos_down) in a column left of it.
        // Num 3 is SexLab's free camera (display only), Num 7 is SkyrimNet's. Focus keys 1-4 are fixed.
        // take_control (Num *) also works outside the HUD (crosshair NPC scene).
        constexpr KeyBinding kBindings[] = {
            { "take_control", "sexlab.hud.key_take_control", VK_MULTIPLY, false },
            { "pos_up", "sexlab.hud.key_pos_up", VK_PRIOR, false },
            { "pos_down", "sexlab.hud.key_pos_down", VK_NEXT, false },
            { "end", "sexlab.hud.key_end", VK_NUMPAD2, false },
            { "previous", "sexlab.hud.key_previous", VK_NUMPAD4, false },
            { "next", "sexlab.hud.key_next", VK_NUMPAD6, false },
            { "slower", "sexlab.hud.key_slower", VK_SUBTRACT, false },
            { "faster", "sexlab.hud.key_faster", VK_ADD, false },
            { "pause", "sexlab.hud.key_pause", VK_NUMPAD5, false },
            { "calm", "sexlab.minigame.key_calm", VK_NUMPAD8, true },
            { "arouse", "sexlab.minigame.key_arouse", VK_NUMPAD9, true },
            { "deny", "sexlab.hud.key_deny", VK_NUMPAD1, false },
            { "punish", "sexlab.hud.key_punish", VK_DECIMAL, false, "sexlab.minigame.key_force" },
            { "aid", "sexlab.minigame.key_aid", VK_RETURN, true },  // Num Enter
        };
        constexpr std::uint32_t kFreeCameraDx = 0x51;  // Num 3
        constexpr std::uint32_t kSkyrimNetDx = 0x47;   // Num 7
        constexpr std::uint32_t kMouseCalmDx = 256;    // LMB (sexlab.minigame.mouse)
        constexpr std::uint32_t kMouseArouseDx = 257;  // RMB

        // View state lives in UiEngine (Magelight v4 preferred, PrismaUI V1 fallback).
        std::atomic<bool> g_domReady{ false };
        bool g_shown = false;

        std::mutex g_lock;
        bool g_showEnjoyment = true;
        bool g_showControls = true;
        bool g_miniGame = false;
        bool g_miniGameMouse = true;   // LMB calm / RMB arouse
        std::map<std::string, int> g_keyVk;            // control -> VK (dashboard value)
        std::map<std::string, std::uint32_t> g_keyDx;  // control -> DX
        std::map<std::string, std::string> g_keyLabel;

        // Focus: an actor of the HUD's scene (by FormID so a reorder keeps it).
        RE::FormID g_focus = 0;
        std::vector<RE::FormID> g_sceneActors;
        std::string g_lastPush;

        // Take control: the NPC the player drives with the HUD keys (0: none, the HUD is the player's own scene).
        RE::FormID g_anchor = 0;
        std::uint32_t g_takeControlDx = 0;  // the take_control key's global (outside the HUD) binding

        // Aid cell: whether the player has an affordable healing / stamina spell or a potion (inventory scan,
        // refreshed at most every kAidCheckInterval seconds).
        constexpr double kAidCheckInterval = 1.0;
        bool g_aidEnabled = false;
        double g_aidCheckedAt = -1.0;

        // Faster/slower narration debounce: net steps since the first press of the burst.
        int g_speedSteps = 0;
        int g_speedLevel = -1;  // level after the last press
        double g_speedLastPress = 0.0;

        double Now()
        {
            using namespace std::chrono;
            static const auto start = steady_clock::now();
            return duration<double>(steady_clock::now() - start).count();
        }

        RE::Actor* ActorFor(RE::FormID id)
        {
            return id ? RE::TESForm::LookupByID<RE::Actor>(id) : nullptr;
        }

        std::string NameOf(RE::Actor* actor)
        {
            const char* name = actor ? actor->GetDisplayFullName() : nullptr;
            return name ? name : "";
        }

        RE::TESQuest* FindMainQuest()
        {
            auto* quest = RE::TESForm::LookupByEditorID<RE::TESQuest>("SkyrimNet_SexLab");
            if (!quest) {
                if (auto* dh = RE::TESDataHandler::GetSingleton()) {
                    quest = dh->LookupForm<RE::TESQuest>(0x800, "SkyrimNet_SexLab.esp");
                }
            }
            return quest;
        }

        // Caller holds g_lock. The actor the HUD keys act as: the NPC the player took control of, else the player.
        RE::Actor* ActingLocked()
        {
            RE::Actor* npc = ActorFor(g_anchor);
            return npc ? npc : RE::PlayerCharacter::GetSingleton();
        }

        RE::Actor* Acting()
        {
            std::lock_guard lock(g_lock);
            return ActingLocked();
        }

        // end / previous / next / pause / deny / pos_up / pos_down / speak are SexLab thread operations (speak:
        // the player's auto-play line): Papyrus Menu.Hud_OnKey. focus: the HUD focus actor (deny), 0 for the
        // rest. The NPC the player took control of goes along as the anchor (None: the player's own scene).
        void DispatchMenuKey(const char* control, RE::FormID focus = 0)
        {
            const std::string ctl = control;
            RE::FormID anchor = 0;
            {
                std::lock_guard lock(g_lock);
                anchor = g_anchor;
            }
            SKSE::GetTaskInterface()->AddTask([ctl, focus, anchor]() {
                auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
                RE::TESQuest* quest = FindMainQuest();
                if (!vm || !quest) {
                    webui_log::error("Hud: cannot dispatch {} (vm/quest missing)", ctl);
                    return;
                }
                auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
                    static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
                RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
                vm->FindBoundObject(handle, "SkyrimNet_SexLab_Menu", scriptObject);
                if (!scriptObject) {
                    webui_log::error("Hud: Menu script not bound");
                    return;
                }
                auto* args =
                    RE::MakeFunctionArguments(RE::BSFixedString(ctl.c_str()), ActorFor(focus), ActorFor(anchor));
                RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
                vm->DispatchMethodCall(scriptObject, RE::BSFixedString("Hud_OnKey"), args, callback);
            });
        }

        void SetFocusIndex(std::size_t index)
        {
            std::lock_guard lock(g_lock);
            if (index < g_sceneActors.size()) {
                g_focus = g_sceneActors[index];
                g_lastPush.clear();
            }
        }

        // The game's keyboard state (DirectInput). Not GetAsyncKeyState: with NumLock on, Windows sends a fake
        // Shift-up before a Shift+numpad key. Reads curState inline: BSWin32KeyboardDevice::IsPressed does not
        // link (its .obj pulls in unresolved device virtuals).
        bool ShiftHeld()
        {
            auto* input = RE::BSInputDeviceManager::GetSingleton();
            auto* kb = input ? input->GetKeyboard() : nullptr;
            if (!kb) {
                return false;
            }
            const auto& state = kb->GetRuntimeData().curState;
            return (state[0x2A] & 0x80) != 0 || (state[0x36] & 0x80) != 0;  // LShift / RShift
        }

        // Caller holds g_lock. Shift target: the actor after the focus in the list, wrapping (1->2, 2->1).
        RE::FormID ShiftTargetLocked()
        {
            const auto it = std::find(g_sceneActors.begin(), g_sceneActors.end(), g_focus);
            if (it == g_sceneActors.end()) {
                return g_focus;
            }
            const auto next = static_cast<std::size_t>(it - g_sceneActors.begin() + 1) % g_sceneActors.size();
            return g_sceneActors[next];
        }

        // Arouse / calm the focus actor; with Shift held, the next actor instead (focus unchanged). The player does
        // it and pays, also while controlling an NPC in a scene they aren't in.
        void OnArouseOrCalm(bool arouse)
        {
            RE::Actor* source = nullptr;
            RE::Actor* target = nullptr;
            {
                const bool shift = ShiftHeld();
                std::lock_guard lock(g_lock);
                source = RE::PlayerCharacter::GetSingleton();
                target = ActorFor(shift ? ShiftTargetLocked() : g_focus);
            }
            if (!source || !target) {
                return;
            }
            const bool ok = arouse ? OrgasmEngine::Arouse(source, target, 1.0f)
                                   : OrgasmEngine::Calm(source, target, 1.0f);
            if (!ok) {
                webui_log::info("Hud: {} refused (cost)", arouse ? "arouse" : "calm");
            }
            std::lock_guard lock(g_lock);
            g_lastPush.clear();
        }

        void OnSpeed(bool faster)
        {
            RE::Actor* acting = Acting();
            const int before = OrgasmEngine::GetSceneSpeedLevel(acting);
            const int level = OrgasmEngine::StepSceneSpeed(acting, faster ? 1 : -1);
            if (level < 0 || level == before) {
                return;
            }
            std::lock_guard lock(g_lock);
            g_speedSteps += faster ? 1 : -1;
            g_speedLevel = level;
            g_speedLastPress = Now();
            g_lastPush.clear();
        }

        // Caller holds g_lock. Default focus: first actor other than the acting one (the player, or the NPC the
        // player took control of) from position 0; the acting actor when solo.
        void ResolveFocus(const std::vector<OrgasmEngine::ActorView>& actors, RE::FormID actingId)
        {
            std::vector<RE::FormID> ids;
            for (const auto& a : actors) {
                ids.push_back(a.id);
            }
            g_sceneActors = std::move(ids);
            if (std::find(g_sceneActors.begin(), g_sceneActors.end(), g_focus) != g_sceneActors.end()) {
                return;
            }
            g_focus = g_sceneActors.empty() ? 0 : g_sceneActors.front();
            for (const auto id : g_sceneActors) {
                if (id != actingId) {
                    g_focus = id;
                    break;
                }
            }
        }

        // Body-part pulldown: the actor's sex (pussy / cock), "" when unknown.
        bool IsFemaleId(RE::FormID id)
        {
            const auto* a = RE::TESForm::LookupByID<RE::Actor>(id);
            const auto* base = a ? a->GetActorBase() : nullptr;
            return base && base->GetSex() == RE::SEX::kFemale;
        }

        void ShowPanel(const char* fn, const nlohmann::json& cfg)
        {
            const std::string payload = cfg.dump(-1, ' ', false, nlohmann::json::error_handler_t::replace);
            WebUI_Invoke(std::string(fn) + "(" + payload + ");");
            WebUI_Visibility_Show(false);
        }

        // Injury Engine's External_PartPoints JSON -> the panel's actor "injury": {total, max, parts: {<term>: {points, max}}}.
        // null when empty or unreadable.
        nlohmann::json InjuryOf(const std::string& text)
        {
            const auto j = nlohmann::json::parse(text, nullptr, false);
            if (j.is_discarded() || !j.is_object() || !j.contains("parts")) {
                return nullptr;
            }
            nlohmann::json parts = nlohmann::json::object();
            for (const auto& p : j["parts"]) {
                parts[InjuryEngine::PartTerm(p.value("name", ""))] = { { "points", p.value("points", 0) },
                    { "max", p.value("max", 0) } };
            }
            return { { "total", j.value("total", 0) }, { "max", j.value("max", 0) }, { "parts", std::move(parts) } };
        }

        // Opens a panel on the game thread with Injury Engine's state added (installed / sexual parts on / max strikes)
        // and, when Injury Engine has External_PartPoints, each actor's torture points per part ("injury"): the panel
        // opens once every actor's points are in (or straight away when none could be asked for).
        void OpenPanel(const char* fn, nlohmann::json cfg)
        {
            SKSE::GetTaskInterface()->AddTask([fn, cfg = std::move(cfg)]() mutable {
                cfg["injuryengine"] = InjuryEngine::Installed();
                cfg["injuryengineSexual"] = cfg["injuryengine"].get<bool>() && InjuryEngine::SexualParts();
                cfg["injuryengineMaxStrikes"] = cfg["injuryengine"].get<bool>() ? InjuryEngine::MaxStrikes() : 1;
                struct Pending
                {
                    std::mutex lock;
                    nlohmann::json cfg;
                    std::size_t left = 0;
                };
                auto pending = std::make_shared<Pending>();
                pending->cfg = std::move(cfg);
                const auto ids = [&]() {
                    std::vector<RE::FormID> out;
                    for (const auto& a : pending->cfg["actors"]) {
                        out.push_back(a.value("id", RE::FormID{ 0 }));
                    }
                    return out;
                }();
                pending->left = ids.size();
                std::size_t asked = 0;
                if (pending->cfg["injuryengine"].get<bool>()) {
                    for (std::size_t i = 0; i < ids.size(); ++i) {
                        const bool ok = InjuryEngine::PartPoints(ActorFor(ids[i]), [pending, fn, i](std::string text) {
                            auto injury = InjuryOf(text);
                            std::lock_guard lock(pending->lock);
                            if (!injury.is_null()) {
                                pending->cfg["actors"][i]["injury"] = std::move(injury);
                            }
                            if (--pending->left == 0) {
                                SKSE::GetTaskInterface()->AddTask([pending, fn]() { ShowPanel(fn, pending->cfg); });
                            }
                        });
                        if (!ok) {
                            break;
                        }
                        ++asked;
                    }
                }
                // The actors not asked for count as answered; when that settles the last one, open here (otherwise
                // the last callback opens it).
                const std::size_t skipped = ids.size() - asked;
                std::lock_guard lock(pending->lock);
                pending->left -= skipped;
                if (pending->left == 0 && (skipped > 0 || ids.empty())) {
                    ShowPanel(fn, pending->cfg);
                }
            });
        }

        // Ask / Order / Punish key (anyone in a managed scene): the panel, solo in the WebUI. Every actor of the
        // acting actor's scene can be the subject (default: the acting actor) or the object; each brings its punish
        // spells (Aid::PunishSpells: weak attack or Injury Engine torture) and, as an object, the requests it could be asked
        // for (strategy order phrases), its punishment reasons (held ones, then an AI actor's current strategy) and
        // its first times this scene (firstTimes: "pussy" / "ass", Lover's Ledger).
        // The panel replies through WebUI onPunishResult.
        // While controlling an NPC the player is the default subject and every actor of that scene is listed after.
        void OnPunish()
        {
            RE::Actor* acting = RE::PlayerCharacter::GetSingleton();
            std::vector<OrgasmEngine::PunishTarget> others;
            if (!acting || !OrgasmEngine::GetPunishInfo(acting, others) || others.empty()) {
                webui_log::info("Hud: punish ignored (not in a managed scene / alone)");
                return;
            }
            std::vector<std::pair<RE::FormID, std::string>> everyone{ { acting->GetFormID(), NameOf(acting) } };
            for (const auto& o : others) {
                everyone.emplace_back(o.id, o.name);
            }
            nlohmann::json list = nlohmann::json::array();
            for (const auto& [id, name] : everyone) {
                nlohmann::json spells = nlohmann::json::array();
                for (const auto& sp : Aid::PunishSpells(ActorFor(id))) {
                    spells.push_back(sp.name);
                }
                nlohmann::json requests = nlohmann::json::array();
                for (const auto& r : OrgasmEngine::GetRequestOptions(id)) {
                    requests.push_back({ { "key", r.key }, { "text", r.text } });
                }
                auto* player = RE::PlayerCharacter::GetSingleton();
                list.push_back({ { "id", id }, { "name", name }, { "female", IsFemaleId(id) },
                    { "isPlayer", player && id == player->GetFormID() }, { "spells", std::move(spells) },
                    { "requests", std::move(requests) }, { "reasons", OrgasmEngine::GetPunishReasons(id) },
                    { "firstTimes", OrgasmEngine::GetFirstTimes(id) } });
            }
            nlohmann::json cfg;
            cfg["actors"] = std::move(list);
            cfg["defaultPunisher"] = acting->GetFormID();
            OpenPanel("openPunishPanel", std::move(cfg));
        }

        // Aid key (mini-game): the Aid panel, solo in the WebUI. Every scene actor (player first) can be the subject
        // (default: the player) or the object; each brings its own healing / stamina spells and potions. The panel
        // replies through WebUI onAidResult.
        // While controlling an NPC: the player (caster, not in the scene) and the actors of the controlled scene.
        void OnAid()
        {
            RE::Actor* acting = Acting();
            auto* player = RE::PlayerCharacter::GetSingleton();
            std::vector<OrgasmEngine::ActorView> actors;
            if (!player || !acting || !OrgasmEngine::GetActorScene(acting, actors)) {
                return;
            }
            const auto options = Aid::ListOptions(player);
            if (options.empty()) {
                webui_log::info("Hud: aid ignored (no healing / stamina spell or potion)");
                return;
            }
            const auto optionsJson = [](const std::vector<Aid::Option>& list) {
                nlohmann::json opts = nlohmann::json::array();
                for (const auto& o : list) {
                    opts.push_back({ { "id", o.form }, { "name", o.name }, { "potion", o.potion }, { "count", o.count },
                        { "cost", static_cast<int>(o.cost + 0.5f) }, { "affordable", o.affordable },
                        { "health", o.health > 0.0f }, { "stamina", o.stamina > 0.0f },
                        { "perCast", static_cast<int>((o.health > 0.0f ? o.health : o.stamina) + 0.5f) } });
                }
                return opts;
            };
            // Health the actor is missing: the panel's default points to heal.
            const auto missingHealth = [](RE::Actor* actor) {
                auto* av = actor ? actor->AsActorValueOwner() : nullptr;
                return av ? static_cast<int>(std::max(0.0f, av->GetPermanentActorValue(RE::ActorValue::kHealth) -
                                                                av->GetActorValue(RE::ActorValue::kHealth)) +
                                             0.5f)
                          : 0;
            };
            nlohmann::json cfg;
            nlohmann::json list = nlohmann::json::array();
            list.push_back({ { "id", player->GetFormID() }, { "name", NameOf(player) },
                { "female", IsFemaleId(player->GetFormID()) }, { "isPlayer", true },
                { "missingHealth", missingHealth(player) }, { "options", optionsJson(options) },
                { "firstTimes", OrgasmEngine::GetFirstTimes(player->GetFormID()) } });
            for (const auto& a : actors) {
                if (a.id != player->GetFormID()) {
                    auto* actor = ActorFor(a.id);
                    list.push_back({ { "id", a.id }, { "name", a.name }, { "female", IsFemaleId(a.id) },
                        { "isPlayer", false }, { "missingHealth", missingHealth(actor) },
                        { "options", optionsJson(Aid::ListOptions(actor)) },
                        { "firstTimes", OrgasmEngine::GetFirstTimes(a.id) } });
                }
            }
            cfg["actors"] = std::move(list);
            cfg["defaultSubject"] = player->GetFormID();
            OpenPanel("openAidPanel", std::move(cfg));
        }

        bool BlockingMenuOpen()
        {
            auto* ui = RE::UI::GetSingleton();
            if (!ui) {
                return true;
            }
            return ui->GameIsPaused() || ui->IsMenuOpen(RE::DialogueMenu::MENU_NAME) ||
                   ui->IsMenuOpen(RE::Console::MENU_NAME) || ui->IsMenuOpen(RE::LoadingMenu::MENU_NAME) ||
                   ui->IsMenuOpen(RE::MainMenu::MENU_NAME);
        }

        void Show(bool show)
        {
            if (!g_domReady.load() || !UiEngine::HudIsValid()) {
                return;
            }
            if (show == g_shown) {
                return;
            }
            g_shown = show;
            if (show) {
                UiEngine::HudShow();
            } else {
                UiEngine::HudHide();
            }
        }

        RE::Actor* CrosshairActor()
        {
            auto* pick = RE::CrosshairPickData::GetSingleton();
            if (!pick) {
                return nullptr;
            }
            const auto ref = pick->GetActiveTarget().get();
            return ref ? ref->As<RE::Actor>() : nullptr;
        }

        // Lets go of the NPC the player took control of (its strategy played all along).
        void ReleaseControl()
        {
            RE::FormID anchor = 0;
            {
                std::lock_guard lock(g_lock);
                anchor = g_anchor;
                g_anchor = 0;
                g_focus = 0;
                g_lastPush.clear();
            }
            if (anchor != 0) {
                OrgasmEngine::SetPlayerDriven(ActorFor(anchor), false);
                webui_log::info("Hud: released control of {:#x}", anchor);
            }
        }

        // Take-control key. In the player's own scene: auto play on / off. Otherwise: release the NPC the player
        // controls, or take control of the crosshair actor when it is in a managed scene.
        void OnTakeControl()
        {
            auto* player = RE::PlayerCharacter::GetSingleton();
            std::int32_t sid = 0;
            if (OrgasmEngine::SceneIdOf(player, sid)) {
                const bool on = !OrgasmEngine::IsAutoPlay();
                if (OrgasmEngine::SetAutoPlay(on) && on) {
                    StrategyDecision::OnAutoPlay();
                }
                std::lock_guard lock(g_lock);
                g_lastPush.clear();
                return;
            }
            RE::FormID anchor = 0;
            {
                std::lock_guard lock(g_lock);
                anchor = g_anchor;
            }
            if (anchor != 0) {
                ReleaseControl();
                return;
            }
            RE::Actor* target = CrosshairActor();
            if (!target || target == player || !OrgasmEngine::SceneIdOf(target, sid)) {
                webui_log::info("Hud: take control ignored (no crosshair actor in a managed scene)");
                return;
            }
            if (!OrgasmEngine::SetPlayerDriven(target, true)) {
                return;
            }
            std::lock_guard lock(g_lock);
            g_anchor = target->GetFormID();
            g_focus = 0;
            g_lastPush.clear();
            webui_log::info("Hud: took control of {:#x} (scene {})", g_anchor, sid);
        }

        void RebindKeys()
        {
            std::map<std::uint32_t, KeyCallback> keys;
            std::map<std::string, std::uint32_t> dx;
            bool controls = false;
            bool miniGame = false;
            bool mouse = false;
            {
                std::lock_guard lock(g_lock);
                dx = g_keyDx;
                controls = g_showControls;
                miniGame = g_miniGame;
                mouse = g_miniGameMouse;
            }
            for (const auto& b : kBindings) {
                const auto it = dx.find(b.control);
                if (it == dx.end() || it->second == 0) {
                    continue;
                }
                if ((b.miniGame && !miniGame) || (!b.miniGame && !controls)) {
                    continue;
                }
                const std::string ctl = b.control;
                KeyCallback cb;
                if (ctl == "take_control") {
                    cb = []() { OnTakeControl(); };
                } else if (ctl == "calm") {
                    cb = []() { OnArouseOrCalm(false); };
                } else if (ctl == "arouse") {
                    cb = []() { OnArouseOrCalm(true); };
                } else if (ctl == "slower") {
                    cb = []() { OnSpeed(false); };
                } else if (ctl == "faster") {
                    cb = []() { OnSpeed(true); };
                } else if (ctl == "punish") {
                    cb = []() { OnPunish(); };
                } else if (ctl == "aid") {
                    cb = []() { OnAid(); };
                } else if (ctl == "deny") {
                    cb = []() {
                        RE::FormID focus = 0;
                        {
                            std::lock_guard lock(g_lock);
                            focus = g_focus;
                            g_lastPush.clear();
                        }
                        DispatchMenuKey("deny", focus);
                    };
                } else {
                    cb = [ctl]() { DispatchMenuKey(ctl.c_str()); };
                }
                keys[it->second] = std::move(cb);
            }
            if (miniGame) {
                // Fixed focus keys 1-4 (DX 0x02..0x05) select positions 0-3.
                for (std::size_t i = 0; i < 4; ++i) {
                    keys[static_cast<std::uint32_t>(0x02 + i)] = [i]() { SetFocusIndex(i); };
                }
                if (mouse) {
                    // LMB calms, RMB arouses (alongside the dashboard keys).
                    keys[kMouseCalmDx] = []() { OnArouseOrCalm(false); };
                    keys[kMouseArouseDx] = []() { OnArouseOrCalm(true); };
                }
            }
            KeyHandler::GetSingleton()->SetHudKeys(std::move(keys));

            // Take control outside the HUD (the player in no scene): a global binding, not consumed. While the HUD
            // is up its own binding runs instead.
            const auto take = dx.find("take_control");
            const std::uint32_t takeDx = controls && take != dx.end() ? take->second : 0;
            auto* handler = KeyHandler::GetSingleton();
            if (g_takeControlDx != 0 && g_takeControlDx != takeDx) {
                handler->Unregister(g_takeControlDx);
            }
            if (takeDx != 0) {
                handler->Register(takeDx, []() {
                    if (WebUI_IsHidden() && !BlockingMenuOpen()) {
                        OnTakeControl();
                    }
                });
            }
            g_takeControlDx = takeDx;
        }
    }

    std::string DxLabel(std::uint32_t dx)
    {
        switch (dx) {
        case 256:
            return "LMB";
        case 257:
            return "RMB";
        case 258:
            return "MMB";
        // hud.html draws arrows for Up / Down / Left / Right.
        case 0xC8:
            return "Up";
        case 0xD0:
            return "Down";
        case 0xCB:
            return "Left";
        case 0xCD:
            return "Right";
        case 0xCF:
            return "End";
        case 0xC7:
            return "Home";
        case 0xC9:
            return "PgUp";
        case 0xD1:
            return "PgDn";
        case 0xD2:
            return "Ins";
        case 0xD3:
            return "Del";
        case 0xC5:
            return "Pause";
        case 0x53:
            return "Num .";
        case 0x52:
            return "Num 0";
        case 0xB5:
            return "Num /";
        case 0x8D:
            return "Num =";
        case 0x9C:
            return "Num Enter";
        default:
            break;
        }
        char buf[64] = {};
        const LONG lparam = static_cast<LONG>((dx & 0x7F) << 16) | ((dx & 0x80) ? (1 << 24) : 0);
        if (dx != 0 && GetKeyNameTextA(lparam, buf, sizeof(buf)) > 0) {
            return buf;
        }
        return "?";
    }

    void Init()
    {
        static std::once_flag once;
        std::call_once(once, []() {
            UiEngine::Init();
            if (!UiEngine::Available()) {
                webui_log::critical("Hud: no UI engine (Magelight or PrismaUI) available");
                return;
            }
            g_domReady = false;
            // Both engines read the same folder: Data/PrismaUI/views/SkyrimNet_SexLab/.
            UiEngine::CreateHudView([]() {
                g_domReady = true;
                webui_log::info("Hud: DomReady");
            });
            if (!UiEngine::HudIsValid()) {
                webui_log::critical("Hud: CreateView failed (missing Data/PrismaUI/views/SkyrimNet_SexLab/hud.html?)");
                return;
            }
            g_shown = false;
            webui_log::info("Hud: view created");
        });
    }

    void ApplyConfig()
    {
        {
            std::lock_guard lock(g_lock);
            g_showEnjoyment = SexLabNet::GetConfigBool("sexlab.hud.enjoyment", true);
            g_showControls = SexLabNet::GetConfigBool("sexlab.hud.controls", true);
            g_miniGame = SexLabNet::IsMiniGameMode() && !SexLabNet::IsOrgasmEngineDisabled();
            g_miniGameMouse = SexLabNet::GetConfigBool("sexlab.minigame.mouse", true);
            g_keyVk.clear();
            g_keyDx.clear();
            g_keyLabel.clear();
            for (const auto& b : kBindings) {
                int vk = SexLabNet::GetConfigInt(b.path, b.defaultVk);
                if (vk == b.defaultVk && b.legacyPath) {
                    vk = SexLabNet::GetConfigInt(b.legacyPath, b.defaultVk);
                }
                const auto dx = SexLabNet::HotkeyVkToDx(vk);
                g_keyVk[b.control] = vk;
                g_keyDx[b.control] = dx;
                g_keyLabel[b.control] = dx ? DxLabel(dx) : "";
            }
            g_lastPush.clear();
            webui_log::info("Hud: config enjoyment={} controls={} minigame={} mouse={}", g_showEnjoyment,
                g_showControls, g_miniGame, g_miniGameMouse);
        }
        RebindKeys();
    }

    nlohmann::json HotkeyMapJson()
    {
        std::lock_guard lock(g_lock);
        nlohmann::json out = nlohmann::json::array();
        for (const auto& b : kBindings) {
            const std::uint32_t dx = g_keyDx.count(b.control) ? g_keyDx.at(b.control) : 0;
            out.push_back({
                { "control", b.control },
                { "path", b.path },
                { "group", b.miniGame ? "minigame" : "controls" },
                { "vk", g_keyVk.count(b.control) ? g_keyVk.at(b.control) : b.defaultVk },
                { "dx", dx },
                { "key", g_keyLabel.count(b.control) ? g_keyLabel.at(b.control) : "" },
                { "enabled", dx != 0 && (b.miniGame ? g_miniGame : g_showControls) },
            });
        }
        // Fixed focus keys 1-4 (DX 0x02..0x05), mini-game only.
        for (std::uint32_t i = 0; i < 4; ++i) {
            out.push_back({
                { "control", "focus" + std::to_string(i + 1) },
                { "group", "minigame" },
                { "fixed", true },
                { "dx", 0x02 + i },
                { "key", std::to_string(i + 1) },
                { "enabled", g_miniGame },
            });
        }
        // Fixed mouse buttons, mini-game + sexlab.minigame.mouse only.
        for (const auto& [ctl, dx] : { std::pair{ "calm_mouse", kMouseCalmDx }, std::pair{ "arouse_mouse", kMouseArouseDx } }) {
            out.push_back({
                { "control", ctl },
                { "path", "sexlab.minigame.mouse" },
                { "group", "minigame" },
                { "fixed", true },
                { "dx", dx },
                { "key", DxLabel(dx) },
                { "enabled", g_miniGame && g_miniGameMouse },
            });
        }
        return out;
    }

    void Reset()
    {
        ReleaseControl();
        std::lock_guard lock(g_lock);
        g_focus = 0;
        g_sceneActors.clear();
        g_lastPush.clear();
        g_speedSteps = 0;
        g_speedLevel = -1;
        g_speedLastPress = 0.0;
        g_aidEnabled = false;
        g_aidCheckedAt = -1.0;
    }

    RE::Actor* ActingActor()
    {
        return Acting();
    }

    void PressKey(const std::string& control, RE::FormID focus)
    {
        if (control == "slower" || control == "faster") {
            OnSpeed(control == "faster");
            return;
        }
        {
            std::lock_guard lock(g_lock);
            g_lastPush.clear();
        }
        DispatchMenuKey(control.c_str(), focus);
    }

    void Tick()
    {
        auto* player = RE::PlayerCharacter::GetSingleton();
        std::vector<OrgasmEngine::ActorView> actors;
        RE::FormID anchorId = 0;
        {
            std::lock_guard lock(g_lock);
            anchorId = g_anchor;
        }
        // Control of an NPC ends with its scene, or when the player's own scene starts.
        if (anchorId != 0) {
            std::int32_t sid = 0;
            RE::Actor* npc = ActorFor(anchorId);
            if (OrgasmEngine::SceneIdOf(player, sid) || !npc || !OrgasmEngine::GetActorScene(npc, actors)) {
                ReleaseControl();
                anchorId = 0;
                actors.clear();
            }
        }
        const bool controlling = anchorId != 0;
        RE::Actor* acting = controlling ? ActorFor(anchorId) : player;
        const bool inScene = controlling || OrgasmEngine::GetPlayerScene(actors);

        bool anyGroup = false;
        {
            std::lock_guard lock(g_lock);
            anyGroup = g_showEnjoyment || g_showControls || g_miniGame;
        }
        const bool visible = inScene && anyGroup && WebUI_IsHidden() && !BlockingMenuOpen();
        KeyHandler::GetSingleton()->SetHudActive(visible);
        Show(visible);

        // Speed narration: one line per burst once the presses stop.
        std::string speedMsg;
        RE::Actor* speedTarget = nullptr;
        {
            std::lock_guard lock(g_lock);
            if (g_speedSteps != 0 && Now() - g_speedLastPress >= kSpeedNarrateDelay) {
                speedTarget = ActorFor(g_focus);
                const std::string who = NameOf(acting);
                const std::string with = speedTarget && speedTarget != acting ? " with " + NameOf(speedTarget) : "";
                const std::string to = g_speedLevel >= 0 && g_speedLevel < OrgasmEngine::kSpeedLevelCount
                                           ? std::string(" to ") + OrgasmEngine::kSpeedLevelNames[g_speedLevel]
                                           : "";
                speedMsg = who + (g_speedSteps > 0 ? " picks up the pace" : " slows the pace") + to + with + ".";
                g_speedSteps = 0;
            } else if (!inScene) {
                g_speedSteps = 0;
            }
        }
        if (!speedMsg.empty()) {
            OrgasmEngine::Narrate("sexlab_speed", speedMsg, acting, speedTarget);
        }

        // SexLab's free camera turned off mid-scene: restore the normal camera (Papyrus Menu.Hud_OnKey).
        // Checked before the visibility early-return so a hidden HUD still catches it. Player's own scene only.
        static bool s_wasFreeCam = false;
        const auto* playerCamera = RE::PlayerCamera::GetSingleton();
        const bool ownScene = inScene && !controlling;
        const bool freeCamNow = ownScene && playerCamera && playerCamera->IsInFreeCameraMode();
        if (s_wasFreeCam && !freeCamNow && ownScene) {
            DispatchMenuKey("camera_lock");
        }
        s_wasFreeCam = freeCamNow;

        if (!visible || !g_domReady.load()) {
            return;
        }

        nlohmann::json j;
        {
            std::lock_guard lock(g_lock);
            ResolveFocus(actors, acting ? acting->GetFormID() : 0);
            j["groups"] = { { "enjoyment", g_showEnjoyment }, { "controls", g_showControls },
                { "minigame", g_miniGame } };
            int focusPos = -1;
            nlohmann::json rows = nlohmann::json::array();
            for (std::size_t i = 0; i < actors.size(); ++i) {
                const auto& a = actors[i];
                if (a.id == g_focus) {
                    focusPos = static_cast<int>(i);
                }
                rows.push_back({ { "pos", i }, { "name", a.name },
                    { "enjoyment", static_cast<int>(a.enjoyment + 0.5f) }, { "flash", a.flashing },
                    { "near", a.dom ? a.domChance >= 0.9f : a.enjoyment >= 90.0f }, { "dom", a.dom },
                    { "chance", static_cast<int>(a.domChance * 100.0f + 0.5f) }, { "denied", a.denied }, { "strategy", a.strategy },
                    { "magicka", static_cast<int>(a.magicka + 0.5f) },
                    { "stamina", static_cast<int>(a.stamina + 0.5f) } });
            }
            j["focus"] = focusPos;
            // Shift held (mini-game): the row arouse / calm presses go to instead of the focus.
            int shiftPos = -1;
            if (g_miniGame && ShiftHeld()) {
                const RE::FormID shiftId = ShiftTargetLocked();
                for (std::size_t i = 0; i < actors.size(); ++i) {
                    if (actors[i].id == shiftId) {
                        shiftPos = static_cast<int>(i);
                    }
                }
            }
            j["shiftTarget"] = shiftPos;
            j["actors"] = std::move(rows);
            nlohmann::json keys = nlohmann::json::object();
            for (const auto& [ctl, label] : g_keyLabel) {
                keys[ctl] = label;
            }
            keys["free"] = DxLabel(kFreeCameraDx);
            keys["skyrimnet"] = DxLabel(kSkyrimNetDx);
            j["keys"] = std::move(keys);
        }
        // Punish cell: always shown, greyed out when nobody else is in the scene. The player punishes (as OnPunish),
        // also while controlling an NPC: every actor of that scene is a target, so a solo scene is enabled too.
        {
            std::vector<OrgasmEngine::PunishTarget> targets;
            const bool punishScene = OrgasmEngine::GetPunishInfo(player, targets);
            j["punish"] = { { "show", true }, { "enabled", punishScene && !targets.empty() } };
        }
        // Aid cell (mini-game; also while controlling an NPC, the player casts): greyed out without an affordable healing / stamina spell or
        // a potion.
        {
            bool miniGame = false;
            {
                std::lock_guard lock(g_lock);
                miniGame = g_miniGame;
            }
            if (miniGame && (g_aidCheckedAt < 0.0 || Now() - g_aidCheckedAt >= kAidCheckInterval)) {
                g_aidEnabled = Aid::HasOptions(player);
                g_aidCheckedAt = Now();
            }
            j["aid"] = { { "show", miniGame }, { "enabled", miniGame && g_aidEnabled } };
        }
        // Take-control cell: auto = hand to AI (own scene, manual); control = take back (auto play); release = let go of NPC.
        if (controlling) {
            j["takeControlLabel"] = "release";
        } else if (OrgasmEngine::IsAutoPlay()) {
            j["takeControlLabel"] = "control";
        } else {
            j["takeControlLabel"] = "auto";
        }
        j["acting"] = controlling ? NameOf(acting) : "";
        j["paused"] = OrgasmEngine::IsScenePaused(acting);
        // SexLab's free camera on: Num 3 reads "lock" (a press returns to the normal camera).
        const auto* camera = RE::PlayerCamera::GetSingleton();
        j["freeCam"] = camera && camera->IsInFreeCameraMode();
        int stage = 0, stageCount = 0;
        OrgasmEngine::GetSceneStage(acting, stage, stageCount);
        j["stage"] = stage;
        j["stages"] = stageCount;
        const int speedLevel = OrgasmEngine::GetSceneSpeedLevel(acting);
        // Slower / faster labels name the level a press steps to; "" at either end.
        j["slower"] = speedLevel > 0 ? OrgasmEngine::kSpeedLevelNames[speedLevel - 1] : "";
        j["faster"] = speedLevel >= 0 && speedLevel + 1 < OrgasmEngine::kSpeedLevelCount
                          ? OrgasmEngine::kSpeedLevelNames[speedLevel + 1]
                          : "";
        // The player pays arouse / calm, also while controlling an NPC (payer: the player's bars, not a scene row).
        j["blocked"] = { { "arouse", !OrgasmEngine::CanArouse(player) }, { "calm", !OrgasmEngine::CanCalm(player) } };
        if (controlling) {
            float magicka = 0.0f, stamina = 0.0f;
            OrgasmEngine::GetResourcePct(player, magicka, stamina);
            j["payer"] = { { "name", NameOf(player) }, { "magicka", static_cast<int>(magicka + 0.5f) },
                { "stamina", static_cast<int>(stamina + 0.5f) } };
        }

        const std::string payload = j.dump(-1, ' ', false, nlohmann::json::error_handler_t::replace);
        {
            std::lock_guard lock(g_lock);
            if (payload == g_lastPush) {
                return;
            }
            g_lastPush = payload;
        }
        UiEngine::HudInvokeJS(("hudUpdate(" + payload + ");").c_str());
    }
}
