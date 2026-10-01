#include "Hud.h"

#include "Config.h"
#include "OrgasmEngine.h"
#include "WebUI.h"
#include "WebUI_Log.h"

#include <Windows.h>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <map>
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
        };

        // Dashboard hotkeys (VK). Focus keys 1-4 are fixed.
        constexpr KeyBinding kBindings[] = {
            { "end", "sexlab.hud.key_end", VK_END, false },
            { "previous", "sexlab.hud.key_previous", VK_LEFT, false },
            { "next", "sexlab.hud.key_next", VK_RIGHT, false },
            { "slower", "sexlab.hud.key_slower", VK_DOWN, false },
            { "faster", "sexlab.hud.key_faster", VK_UP, false },
            { "pause", "sexlab.hud.key_pause", VK_HOME, false },
            { "calm", "sexlab.minigame.key_calm", VK_LBUTTON, true },
            { "arouse", "sexlab.minigame.key_arouse", VK_RBUTTON, true },
            { "deny", "sexlab.hud.key_deny", VK_NEXT, false },
        };

        PRISMA_UI_API::IVPrismaUI1* g_prisma = nullptr;
        PrismaView g_view = 0;
        std::atomic<bool> g_domReady{ false };
        bool g_shown = false;

        std::mutex g_lock;
        bool g_showEnjoyment = true;
        bool g_showControls = true;
        bool g_miniGame = false;
        std::map<std::string, std::uint32_t> g_keyDx;  // control -> DX
        std::map<std::string, std::string> g_keyLabel;

        // Focus: an actor of the player's scene (by FormID so a reorder keeps it).
        RE::FormID g_focus = 0;
        std::vector<RE::FormID> g_sceneActors;
        std::string g_lastPush;

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

        // end / previous / next / pause / deny are SexLab thread operations: Papyrus Menu.Hud_OnKey.
        // focus: the HUD focus actor (deny), 0 for the rest.
        void DispatchMenuKey(const char* control, RE::FormID focus = 0)
        {
            const std::string ctl = control;
            SKSE::GetTaskInterface()->AddTask([ctl, focus]() {
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
                auto* args = RE::MakeFunctionArguments(RE::BSFixedString(ctl.c_str()), ActorFor(focus));
                RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
                vm->DispatchMethodCall(scriptObject, RE::BSFixedString("Hud_OnKey"), args, callback);
            });
        }

        RE::Actor* FocusActor()
        {
            std::lock_guard lock(g_lock);
            return ActorFor(g_focus);
        }

        void SetFocusIndex(std::size_t index)
        {
            std::lock_guard lock(g_lock);
            if (index < g_sceneActors.size()) {
                g_focus = g_sceneActors[index];
                g_lastPush.clear();
            }
        }

        void OnArouseOrCalm(bool arouse)
        {
            auto* player = RE::PlayerCharacter::GetSingleton();
            auto* target = FocusActor();
            if (!player || !target) {
                return;
            }
            const bool ok = arouse ? OrgasmEngine::Arouse(player, target, 1.0f)
                                   : OrgasmEngine::Calm(player, target, 1.0f);
            if (!ok) {
                webui_log::info("Hud: {} refused (cost / broken)", arouse ? "arouse" : "calm");
            }
            std::lock_guard lock(g_lock);
            g_lastPush.clear();
        }

        void OnSpeed(bool faster)
        {
            const int before = OrgasmEngine::GetPlayerSceneSpeedLevel();
            const int level = OrgasmEngine::StepPlayerSceneSpeed(faster ? 1 : -1);
            if (level < 0 || level == before) {
                return;
            }
            std::lock_guard lock(g_lock);
            g_speedSteps += faster ? 1 : -1;
            g_speedLevel = level;
            g_speedLastPress = Now();
            g_lastPush.clear();
        }

        // Caller holds g_lock. Default focus: first non-player from position 0, the player when solo.
        void ResolveFocus(const std::vector<OrgasmEngine::ActorView>& actors)
        {
            std::vector<RE::FormID> ids;
            for (const auto& a : actors) {
                ids.push_back(a.id);
            }
            g_sceneActors = std::move(ids);
            if (std::find(g_sceneActors.begin(), g_sceneActors.end(), g_focus) != g_sceneActors.end()) {
                return;
            }
            const auto* player = RE::PlayerCharacter::GetSingleton();
            const RE::FormID playerId = player ? player->GetFormID() : 0;
            g_focus = g_sceneActors.empty() ? 0 : g_sceneActors.front();
            for (const auto id : g_sceneActors) {
                if (id != playerId) {
                    g_focus = id;
                    break;
                }
            }
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
            if (!g_prisma || !g_domReady.load() || !g_prisma->IsValid(g_view)) {
                return;
            }
            if (show == g_shown) {
                return;
            }
            g_shown = show;
            if (show) {
                g_prisma->Show(g_view);
            } else {
                g_prisma->Hide(g_view);
            }
        }

        void RebindKeys()
        {
            std::map<std::uint32_t, KeyCallback> keys;
            std::map<std::string, std::uint32_t> dx;
            bool controls = false;
            bool miniGame = false;
            {
                std::lock_guard lock(g_lock);
                dx = g_keyDx;
                controls = g_showControls;
                miniGame = g_miniGame;
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
                if (ctl == "calm") {
                    cb = []() { OnArouseOrCalm(false); };
                } else if (ctl == "arouse") {
                    cb = []() { OnArouseOrCalm(true); };
                } else if (ctl == "slower") {
                    cb = []() { OnSpeed(false); };
                } else if (ctl == "faster") {
                    cb = []() { OnSpeed(true); };
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
            }
            KeyHandler::GetSingleton()->SetHudKeys(std::move(keys));
        }
    }

    void Init()
    {
        static std::once_flag once;
        std::call_once(once, []() {
            g_prisma = static_cast<PRISMA_UI_API::IVPrismaUI1*>(
                PRISMA_UI_API::RequestPluginAPI(PRISMA_UI_API::InterfaceVersion::V1));
            if (!g_prisma) {
                webui_log::critical("Hud: PrismaUI API missing");
                return;
            }
            g_domReady = false;
            // Resolves under Data/PrismaUI/views/.
            g_view = g_prisma->CreateView("SkyrimNet_SexLab/hud.html", [](PrismaView view) {
                g_view = view;
                g_domReady = true;
                webui_log::info("Hud: DomReady");
            });
            if (!g_prisma->IsValid(g_view)) {
                webui_log::critical("Hud: CreateView failed (missing PrismaUI/views/SkyrimNet_SexLab/hud.html?)");
                return;
            }
            g_prisma->Hide(g_view);
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
            g_miniGame = SexLabNet::GetConfigBool("sexlab.minigame.enabled", false);
            g_keyDx.clear();
            g_keyLabel.clear();
            for (const auto& b : kBindings) {
                const int vk = SexLabNet::GetConfigInt(b.path, b.defaultVk);
                const auto dx = SexLabNet::HotkeyVkToDx(vk);
                g_keyDx[b.control] = dx;
                g_keyLabel[b.control] = dx ? DxLabel(dx) : "";
            }
            g_lastPush.clear();
            webui_log::info("Hud: config enjoyment={} controls={} minigame={}", g_showEnjoyment, g_showControls,
                g_miniGame);
        }
        RebindKeys();
    }

    void Reset()
    {
        std::lock_guard lock(g_lock);
        g_focus = 0;
        g_sceneActors.clear();
        g_lastPush.clear();
        g_speedSteps = 0;
        g_speedLevel = -1;
        g_speedLastPress = 0.0;
    }

    void Tick()
    {
        std::vector<OrgasmEngine::ActorView> actors;
        const bool inScene = OrgasmEngine::GetPlayerScene(actors);

        bool anyGroup = false;
        {
            std::lock_guard lock(g_lock);
            anyGroup = g_showEnjoyment || g_showControls || g_miniGame;
        }
        const bool visible = inScene && anyGroup && WebUI_IsHidden() && !BlockingMenuOpen();
        KeyHandler::GetSingleton()->SetHudActive(visible);
        Show(visible);

        auto* player = RE::PlayerCharacter::GetSingleton();

        // Speed narration: one line per burst once the presses stop.
        std::string speedMsg;
        RE::Actor* speedTarget = nullptr;
        {
            std::lock_guard lock(g_lock);
            if (g_speedSteps != 0 && Now() - g_speedLastPress >= kSpeedNarrateDelay) {
                speedTarget = ActorFor(g_focus);
                const std::string who = NameOf(player);
                const std::string with = speedTarget && speedTarget != player ? " with " + NameOf(speedTarget) : "";
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
            OrgasmEngine::Narrate("sexlab_speed", speedMsg, player, speedTarget);
        }

        if (!visible || !g_domReady.load()) {
            return;
        }

        nlohmann::json j;
        {
            std::lock_guard lock(g_lock);
            ResolveFocus(actors);
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
                    { "near", a.enjoyment >= 90.0f }, { "broken", a.broken }, { "dom", a.dom }, { "denied", a.denied },
                    { "magicka", static_cast<int>(a.magicka + 0.5f) },
                    { "stamina", static_cast<int>(a.stamina + 0.5f) } });
            }
            j["focus"] = focusPos;
            j["actors"] = std::move(rows);
            nlohmann::json keys = nlohmann::json::object();
            for (const auto& [ctl, label] : g_keyLabel) {
                keys[ctl] = label;
            }
            j["keys"] = std::move(keys);
        }
        j["paused"] = OrgasmEngine::IsPlayerScenePaused();
        int stage = 0, stageCount = 0;
        OrgasmEngine::GetPlayerSceneStage(stage, stageCount);
        j["stage"] = stage;
        j["stages"] = stageCount;
        const int speedLevel = OrgasmEngine::GetPlayerSceneSpeedLevel();
        j["speed"] = speedLevel >= 0 ? OrgasmEngine::kSpeedLevelNames[speedLevel] : "";
        j["blocked"] = { { "arouse", !OrgasmEngine::CanArouse(player) }, { "calm", !OrgasmEngine::CanCalm(player) },
            { "broken", OrgasmEngine::IsMentallyBroken(player) } };

        const std::string payload = j.dump(-1, ' ', false, nlohmann::json::error_handler_t::replace);
        {
            std::lock_guard lock(g_lock);
            if (payload == g_lastPush) {
                return;
            }
            g_lastPush = payload;
        }
        g_prisma->Invoke(g_view, ("hudUpdate(" + payload + ");").c_str());
    }
}
