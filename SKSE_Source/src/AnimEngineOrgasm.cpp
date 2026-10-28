#include "AnimEngineOrgasm.h"

#include "AnimationDB.h"
#include "Config.h"
#include "JsonUtil.h"
#include "NarrationTiming.h"
#include "OrgasmEngine.h"
#include "StrategyDecision.h"
#include "WebUI_Log.h"

#include <algorithm>
#include <atomic>
#include <cctype>
#include <functional>
#include <map>
#include <mutex>
#include <random>
#include <unordered_set>

namespace AnimEngineOrgasm
{
    namespace
    {
        // Scene.psc ENDING_HOLD_CAP: the final-stage dialogue hold never runs longer.
        constexpr float kEndingHoldCap = 30.f;
        // Victim_Poll: a gate scene past the cap waits this long for the gate before releasing.
        constexpr double kVictimGateGrace = 3.0;
        // Ending_Poll: the dialogue hold looks at the response only after this long.
        constexpr double kEndingMinHold = 2.0;

        using Hold = AnimEngine::Hold;

        /// One wired AnimEngine scene: the Scene script's ending / gate / victim state.
        struct Wired
        {
            int ae_id = 0;
            std::int32_t sid = 0;
            std::string registry;
            std::vector<RE::FormID> actors;
            std::vector<std::int32_t> roles;
            std::vector<bool> expected;
            bool has_player = false;
            int node = -1;
            int stage = 0;
            int count = 0;
            bool at_sink = false;
            bool paused = false;
            // Ending (Ending_RollTarget): the lead's orgasm target; reaching it from the second-to-last stage
            // jumps to the final stage.
            RE::FormID lead = 0;
            std::int32_t target = 0;
            bool ending_done = false;
            bool ending_hold_pending = false;
            bool ending_holding = false;
            double ending_held = 0.0;
            std::int64_t ending_mark = -1;
            // Gate voice wait (Gate_Hold / Gate_Poll).
            bool gate_holding = false;
            int gate_hold_node = -1;
            double gate_held = 0.0;
            // Victim hold (Victim_Hold / Victim_Poll): once per pass through the second-to-last stage.
            bool victim_holding = false;
            int victim_hold_node = -1;
            double victim_held = 0.0;
            bool victim_expired = false;
            std::unordered_set<RE::FormID> denied;
        };

        using Work = std::vector<std::function<void()>>;

        std::mutex g_mutex;  // leaf: nothing below calls out while holding it
        std::map<int, Wired> g_wired;
        std::atomic<std::uint64_t> g_epoch{ 1 };
        std::mt19937 g_rng{ std::random_device{}() };

        RE::Actor* ActorFor(RE::FormID id)
        {
            return id ? RE::TESForm::LookupByID<RE::Actor>(id) : nullptr;
        }

        std::string NameOf(RE::FormID id)
        {
            auto* a = ActorFor(id);
            const char* n = a ? a->GetDisplayFullName() : nullptr;
            return n && *n ? n : std::format("{:08X}", id);
        }

        std::string Names(const std::vector<RE::Actor*>& actors)
        {
            std::string out;
            for (auto* a : actors)
                out += (out.empty() ? "" : ", ") + NameOf(a ? a->GetFormID() : 0);
            return out;
        }

        constexpr const char* kShell = "SkyrimNet_SexLab_AnimEngine";

        void DispatchShell(const char* fn, RE::BSScript::IFunctionArguments* args)
        {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> cb;
            if (!vm || !vm->DispatchStaticCall(RE::BSFixedString(kShell), RE::BSFixedString(fn), args, cb))
                webui_log::warn("AnimEngineOrgasm: {}.{} dispatch failed", kShell, fn);
        }

        /// SexLab's orgasm effect (sound, shake, cum) through the shell's OrgasmEffect.
        void OrgasmEffect(RE::Actor* a)
        {
            if (!a)
                return;
            const auto fx = AnimEngine::OrgasmFxOf(a);
            std::vector<RE::Actor*> to;
            std::vector<std::int32_t> ids;
            for (const auto& [id, cum] : fx.cum) {
                if (auto* t = ActorFor(id)) {
                    to.push_back(t);
                    ids.push_back(cum);
                }
            }
            webui_log::info("AnimEngineOrgasm: orgasm effect {} silent={} cum [{}]", NameOf(a->GetFormID()), fx.silent,
                Names(to));
            DispatchShell("OrgasmEffect", RE::MakeFunctionArguments(static_cast<RE::Actor*>(a), std::move(to),
                                              std::move(ids), static_cast<bool>(fx.silent)));
        }

        // Scene.psc JoinNames / NamesClause / EnjoymentBand / BandLeadIn / PossessivePronoun (orgasm-narration.md).
        std::string JoinNames(const std::vector<std::string>& names)
        {
            const auto n = names.size();
            if (n == 0)
                return "";
            if (n == 1)
                return names[0];
            if (n == 2)
                return names[0] + " and " + names[1];
            std::string s;
            for (std::size_t i = 0; i + 1 < n; ++i)
                s += names[i] + ", ";
            return s + "and " + names.back();
        }

        std::string NamesClause(const std::vector<std::string>& names, const std::string& single, const std::string& plural)
        {
            if (names.empty())
                return "";
            return JoinNames(names) + " " + (names.size() == 1 ? single : plural) + " ";
        }

        int EnjoymentBand(float e)
        {
            const int v = static_cast<int>(e);
            return v <= 30 ? 0 : v <= 60 ? 1 : v < 90 ? 2 : 3;
        }

        const char* BandLeadIn(int band)
        {
            return band == 1 ? "Though aroused, " : band == 2 ? "Although close, " : band == 3 ? "Although on the edge, " : "";
        }

        const char* PossessivePronoun(RE::Actor* a)
        {
            auto* base = a ? a->GetActorBase() : nullptr;
            if (!base)
                return "their";
            return base->GetSex() == RE::SEX::kFemale ? "her" : base->GetSex() == RE::SEX::kMale ? "his" : "their";
        }

        bool EndingEnabled()
        {
            return SexLabNet::GetConfigBool("sexlab.ending.enabled", true);
        }

        Wired* FindLocked(int ae_id)
        {
            const auto it = g_wired.find(ae_id);
            return it == g_wired.end() ? nullptr : &it->second;
        }

        Wired* FindByActorLocked(RE::FormID id)
        {
            for (auto& [ae, w] : g_wired) {
                if (std::find(w.actors.begin(), w.actors.end(), id) != w.actors.end())
                    return &w;
            }
            return nullptr;
        }

        void Run(Work& work)
        {
            for (auto& f : work)
                f();
        }

        bool IsCreature(RE::Actor* a)
        {
            return a && !a->HasKeywordString("ActorTypeNPC");
        }

        bool IsMale(RE::Actor* a)
        {
            auto* base = a ? a->GetActorBase() : nullptr;
            return a && !IsCreature(a) && base && base->GetSex() != RE::SEX::kFemale;
        }

        bool HasTag(const AnimationDB::AnimRow* row, const char* tag)
        {
            if (!row)
                return false;
            const std::string want = tag;
            return std::any_of(row->tags.begin(), row->tags.end(), [&](const std::string& t) {
                return t.size() == want.size() && std::equal(t.begin(), t.end(), want.begin(), [](char x, char y) {
                    return std::tolower(static_cast<unsigned char>(x)) == std::tolower(static_cast<unsigned char>(y));
                });
            });
        }

        void SetHold(Work& work, const Wired& w, Hold hold, bool on, int node)
        {
            const int id = w.ae_id;
            work.push_back([id, hold, on, node]() { AnimEngine::SetHold(id, hold, on, node); });
        }

        // ---- Scene.psc ports (all under g_mutex; engine / AnimEngine calls go into `work`) ----

        float EndingHoldMax(const Wired& w, float cfg_max)
        {
            if (!Narration::EndingDialogue())
                return 0.f;
            float m = std::min(cfg_max, kEndingHoldCap);
            if (!w.has_player)
                m *= 0.5f;
            return m;
        }

        /// Ending_Hold: hold the final stage until the orgasm dialogue has played.
        void EndingHoldLocked(Wired& w, Work& work, float cfg_max)
        {
            w.ending_hold_pending = false;
            const float max = EndingHoldMax(w, cfg_max);
            if (max <= 0.f || w.ending_holding)
                return;
            w.ending_holding = true;
            w.ending_held = 0.0;
            SetHold(work, w, Hold::kEnding, true, w.node);
            webui_log::info("AnimEngineOrgasm: scene {} holding final stage {}/{} max {:.0f}s", w.ae_id, w.stage,
                w.count, max);
        }

        /// Ending_ToFinal.
        void ToFinalLocked(Wired& w, Work& work, float cfg_hold_max)
        {
            w.ending_done = true;
            if (w.stage < w.count) {
                w.ending_hold_pending = true;
                const int id = w.ae_id;
                webui_log::info("AnimEngineOrgasm: scene {} final stage {} -> {}", w.ae_id, w.stage, w.count);
                work.push_back([id]() { AnimEngine::GoToFinal(id); });
            } else {
                EndingHoldLocked(w, work, cfg_hold_max);
            }
        }

        void GateReleaseLocked(Wired& w, Work& work)
        {
            if (!w.gate_holding)
                return;
            w.gate_holding = false;
            SetHold(work, w, Hold::kGate, false, -1);
        }

        void VictimReleaseLocked(Wired& w, Work& work)
        {
            if (!w.victim_holding)
                return;
            w.victim_holding = false;
            SetHold(work, w, Hold::kVictim, false, -1);
        }

        /// Engine_AdvanceToFinal.
        void AdvanceToFinalLocked(Wired& w, Work& work, float cfg_hold_max)
        {
            GateReleaseLocked(w, work);
            webui_log::info("AnimEngineOrgasm: scene {} advance to final, stage {}/{}", w.ae_id, w.stage, w.count);
            if (w.ending_done && w.stage >= w.count)
                return;
            ToFinalLocked(w, work, cfg_hold_max);
        }

        struct GroupFacts
        {
            bool victim_hold_scene = false;
            std::int32_t lead_count = 0;
        };

        /// Victim_AggressorFinished + Ending_Check, after an orgasm group.
        void EndingCheckLocked(Wired& w, const std::vector<RE::FormID>& group, const GroupFacts& f, Work& work,
            bool enabled, float cfg_hold_max)
        {
            const bool second_to_last = w.count >= 2 && w.stage == w.count - 1;
            if (!w.ending_done && enabled && second_to_last && f.victim_hold_scene) {
                for (const auto id : group) {
                    const auto it = std::find(w.actors.begin(), w.actors.end(), id);
                    if (it == w.actors.end())
                        continue;
                    const auto i = static_cast<std::size_t>(it - w.actors.begin());
                    if (i < w.roles.size() && w.roles[i] == 2)
                        continue;
                    webui_log::info("AnimEngineOrgasm: scene {} victim hold: {} orgasmed at stage {}/{}, final stage",
                        w.ae_id, NameOf(id), w.stage, w.count);
                    VictimReleaseLocked(w, work);
                    ToFinalLocked(w, work, cfg_hold_max);
                    return;
                }
            }
            if (w.ending_done || !w.lead || w.target <= 0 || !enabled)
                return;
            if (std::find(group.begin(), group.end(), w.lead) == group.end())
                return;
            if (f.lead_count < w.target) {
                webui_log::info("AnimEngineOrgasm: scene {} lead {} orgasms {}/{}", w.ae_id, NameOf(w.lead),
                    f.lead_count, w.target);
                return;
            }
            if (w.stage < w.count - 1) {
                webui_log::info("AnimEngineOrgasm: scene {} lead {} reached target {}/{} at stage {}/{}, not "
                                "second-to-last: no jump",
                    w.ae_id, NameOf(w.lead), f.lead_count, w.target, w.stage, w.count);
                return;
            }
            webui_log::info("AnimEngineOrgasm: scene {} lead {} reached target {}/{}, final stage", w.ae_id,
                NameOf(w.lead), f.lead_count, w.target);
            ToFinalLocked(w, work, cfg_hold_max);
        }

        /// Victim_StageStart + Ending_StageStart, after the engine has the new stage.
        void StageStartLocked(Wired& w, bool victim_hold_scene, Work& work, bool enabled, float cfg_hold_max)
        {
            // AnimEngine cleared every hold on entering the stage.
            if (w.victim_holding && w.node != w.victim_hold_node) {
                webui_log::info("AnimEngineOrgasm: scene {} stage changed, dropping the victim hold", w.ae_id);
                w.victim_holding = false;
            }
            if (w.gate_holding && w.node != w.gate_hold_node) {
                w.gate_holding = false;
                if (w.stage >= w.count && !w.ending_done) {
                    // Reached the final stage before the gate voice: hold it for the dialogue instead.
                    ToFinalLocked(w, work, cfg_hold_max);
                    return;
                }
                webui_log::info("AnimEngineOrgasm: scene {} stage changed, dropping the gate hold", w.ae_id);
            }
            if (w.stage < w.count - 1) {
                w.victim_hold_node = -1;  // stepping back re-arms the hold, as the engine re-arms its gate
            } else if (!w.victim_holding && !w.gate_holding && !w.ending_done && w.count >= 2 &&
                       w.stage == w.count - 1 && w.victim_hold_node != w.node && enabled && victim_hold_scene) {
                w.victim_holding = true;
                w.victim_expired = false;
                w.victim_held = 0.0;
                w.victim_hold_node = w.node;
                SetHold(work, w, Hold::kVictim, true, w.node);
                webui_log::info("AnimEngineOrgasm: scene {} holding stage {}/{} for an aggressor's orgasm", w.ae_id,
                    w.stage, w.count);
            }
            if (w.ending_hold_pending && w.stage >= w.count)
                EndingHoldLocked(w, work, cfg_hold_max);
            else if (w.ending_holding)
                SetHold(work, w, Hold::kEnding, true, w.node);  // the stage moved under the ending hold
        }

        float HoldMaxConfig()
        {
            return SexLabNet::GetConfigFloat("sexlab.ending.dialogue_hold_max", kEndingHoldCap);
        }

        // ---- First stage: Engine_BeginScene / Engine_SetSkills / Ending_RollTarget ----

        bool BuildWired(const StageNote& n, Wired& out)
        {
            std::vector<RE::Actor*> actors;
            for (const auto id : n.actors) {
                auto* a = ActorFor(id);
                if (!a)
                    return false;
                actors.push_back(a);
            }
            out.ae_id = n.ae_id;
            out.sid = SidOf(n.ae_id);
            out.registry = n.registry;
            out.actors = n.actors;
            out.roles = n.roles.size() == n.actors.size() ? n.roles : std::vector<std::int32_t>(n.actors.size(), 0);
            auto* player = RE::PlayerCharacter::GetSingleton();
            out.has_player = std::find(actors.begin(), actors.end(), player) != actors.end();

            const auto row = AnimationDB::GetByRegistry(n.registry);
            const AnimationDB::AnimRow* r = row ? &*row : nullptr;
            out.expected.assign(actors.size(), true);
            for (std::size_t i = 0; r && i < actors.size() && i < r->pos_no_orgasm.size(); ++i)
                out.expected[i] = r->pos_no_orgasm[i] != 1;

            // Ending_PickLead: no initiator here, so the first position expected to orgasm, else position 0.
            std::size_t lead = 0;
            for (std::size_t i = 0; i < actors.size(); ++i) {
                if (out.expected[i]) {
                    lead = i;
                    break;
                }
            }
            out.lead = out.actors[lead];
            const bool male = IsMale(actors[lead]);
            const std::string which = male ? "male" : "female";
            int lo = SexLabNet::GetConfigInt(("sexlab.ending.target_" + which + "_min").c_str(), 1);
            int hi = SexLabNet::GetConfigInt(("sexlab.ending.target_" + which + "_max").c_str(), male ? 1 : 2);
            lo = std::max(lo, 0);
            hi = std::max(hi, lo);
            out.target = std::uniform_int_distribution<int>(lo, hi)(g_rng);
            return true;
        }

        /// Engine calls for a new wired scene (no bridge lock held).
        void BeginEngine(const Wired& w, const std::string& registry)
        {
            std::vector<RE::Actor*> actors;
            for (const auto id : w.actors)
                actors.push_back(ActorFor(id));
            OrgasmEngine::BeginScene(w.sid, actors, w.roles, std::vector<float>(actors.size(), 0.f), w.has_player);

            const auto row = AnimationDB::GetByRegistry(registry);
            const AnimationDB::AnimRow* r = row ? &*row : nullptr;
            const bool vaginal = HasTag(r, "Vaginal");
            const bool anal = HasTag(r, "Anal");
            const bool oral = HasTag(r, "Oral") || HasTag(r, "Blowjob");
            const int act_skill = vaginal ? 1 : anal ? 2 : (oral || HasTag(r, "Cunnilingus")) ? 3 : 0;
            OrgasmEngine::SetSceneActs(actors.front(), vaginal, anal, oral);
            for (std::size_t i = 0; i < actors.size(); ++i) {
                auto* a = actors[i];
                OrgasmEngine::SetSceneBlocked(a, false);
                OrgasmEngine::SetDomSlave(a, false);
                // SexLab skills / lewd are SexLab's stats: unskilled until a native source exists.
                OrgasmEngine::SetActorSkills(a, 0, 0);
                int low = 0, high = 0;
                bool any = false;
                for (std::size_t j = 0; j < actors.size(); ++j) {
                    if (j == i)
                        continue;
                    const int rank = StrategyDecision::RelationshipRank(a, actors[j]);
                    low = any ? std::min(low, rank) : rank;
                    high = any ? std::max(high, rank) : rank;
                    any = true;
                }
                OrgasmEngine::SetBonusInputs(a, {}, {}, low, high, act_skill);
                OrgasmEngine::SetOrgasmExpected(a, w.expected[i]);
            }
            webui_log::info("AnimEngineOrgasm: scene {} wired sid {} '{}' roles [{}] expected [{}] lead {} target {} "
                            "acts v{} a{} o{} skill {}",
                w.ae_id, w.sid, registry,
                [&] {
                    std::string s;
                    for (const auto x : w.roles)
                        s += (s.empty() ? "" : ",") + std::to_string(x);
                    return s;
                }(),
                [&] {
                    std::string s;
                    for (const bool x : w.expected)
                        s += (s.empty() ? "" : ",") + std::string(x ? "1" : "0");
                    return s;
                }(),
                NameOf(w.lead), w.target, vaginal, anal, oral, act_skill);
        }
    }

    std::uint64_t Epoch()
    {
        return g_epoch.load();
    }

    void OnStage(const StageNote& note)
    {
        if (note.epoch != Epoch())
            return;
        std::int32_t sid = 0;
        if (note.first) {
            if (!SexLabNet::GetConfigBool("sexlab.anim_engine.orgasm_engine", true)) {
                webui_log::info("AnimEngineOrgasm: scene {} not wired (sexlab.anim_engine.orgasm_engine off)",
                    note.ae_id);
                return;
            }
            if (OrgasmEngine::IsEngineDisabled()) {
                webui_log::warn("AnimEngineOrgasm: scene {} not wired (sexlab.enjoyment.engine_disabled: no SexLab "
                                "to own enjoyment in an AnimEngine scene)",
                    note.ae_id);
                return;
            }
            Wired w;
            if (!BuildWired(note, w)) {
                webui_log::warn("AnimEngineOrgasm: scene {} not wired (actor missing)", note.ae_id);
                return;
            }
            BeginEngine(w, note.registry);
            sid = w.sid;
            std::lock_guard lock(g_mutex);
            g_wired[note.ae_id] = std::move(w);
        }
        RE::FormID lead = 0;
        std::int32_t target = 0;
        {
            std::lock_guard lock(g_mutex);
            auto* w = FindLocked(note.ae_id);
            if (!w)
                return;
            sid = w->sid;
            w->node = note.view.node;
            w->stage = note.view.stage;
            w->count = note.view.count;
            w->at_sink = note.view.at_sink;
            lead = w->lead;
            target = w->ending_done ? 0 : w->target;
        }
        // Engine_SetEndingTarget + Engine_SetStage (no LeadIn on AnimEngine).
        const bool enabled = EndingEnabled();
        OrgasmEngine::SetEndingTarget(sid, ActorFor(lead), enabled ? target : 0);
        OrgasmEngine::SetStageTimers(sid, note.view.secs, false);
        OrgasmEngine::SetStage(sid, note.view.stage, note.view.count);
        webui_log::info("AnimEngineOrgasm: scene {} stage {}/{} node '{}'{}{}", note.ae_id, note.view.stage,
            note.view.count, note.node_id, note.view.at_sink ? " (final)" : "", note.view.linear ? "" : " (projected)");
        const bool vhs = OrgasmEngine::IsVictimHoldScene(sid);
        const float hold_max = HoldMaxConfig();
        Work work;
        {
            std::lock_guard lock(g_mutex);
            if (auto* w = FindLocked(note.ae_id))
                StageStartLocked(*w, vhs, work, enabled, hold_max);
        }
        Run(work);
    }

    void OnPause(std::uint64_t epoch, int ae_id, bool paused)
    {
        if (epoch != Epoch())
            return;
        std::int32_t sid = 0;
        {
            std::lock_guard lock(g_mutex);
            auto* w = FindLocked(ae_id);
            if (!w || w->paused == paused)
                return;
            w->paused = paused;
            sid = w->sid;
        }
        OrgasmEngine::SetScenePaused(sid, paused);
    }

    void OnEnd(std::uint64_t epoch, int ae_id, const std::string& why)
    {
        if (epoch != Epoch())
            return;
        std::int32_t sid = 0;
        {
            std::lock_guard lock(g_mutex);
            const auto it = g_wired.find(ae_id);
            if (it == g_wired.end())
                return;
            sid = it->second.sid;
            g_wired.erase(it);
        }
        OrgasmEngine::EndScene(sid);
        webui_log::info("AnimEngineOrgasm: scene {} unwired sid {} ({})", ae_id, sid, why);
    }

    void Clear()
    {
        ++g_epoch;
        std::lock_guard lock(g_mutex);
        if (!g_wired.empty())
            webui_log::info("AnimEngineOrgasm: cleared {} scene(s)", g_wired.size());
        g_wired.clear();
    }

    bool OwnsActor(RE::FormID actor)
    {
        std::lock_guard lock(g_mutex);
        return FindByActorLocked(actor) != nullptr;
    }

    bool IsLive(std::int32_t sid)
    {
        if (!IsAnimEngineSid(sid))
            return false;
        std::lock_guard lock(g_mutex);
        const auto* w = FindLocked(sid - kSidBase);
        return w && w->sid == sid;
    }

    void OnOrgasmGroup(const std::vector<RE::Actor*>& actors, const std::vector<std::int32_t>& forced, bool individual,
        const std::string& source, RE::Actor* allower, RE::Actor* allowed, const std::string& extras)
    {
        if (actors.empty())
            return;
        int ae_id = 0;
        std::int32_t sid = 0;
        RE::FormID lead = 0;
        {
            std::lock_guard lock(g_mutex);
            auto* w = FindByActorLocked(actors.front()->GetFormID());
            if (!w)
                return;
            ae_id = w->ae_id;
            sid = w->sid;
            lead = w->lead;
        }
        webui_log::info("AnimEngineOrgasm: scene {} orgasm [{}] source {}{}", ae_id, Names(actors), source,
            individual ? " individual" : "");
        // Orgasm_ApplyGroup: counts, cooldown and the SkyrimNet_SexLab_Orgasm event already happened in the
        // engine. No SexLab ForceOrgasm / mirror / SLA relief here. A gate rush was narrated at the pass.
        if (source != "gate")
            Narration::OrgasmGroup(ae_id, actors, forced, individual, allower, allowed, extras);
        // The body's orgasm (a gate group too: its narration went out at the pass).
        for (auto* a : actors)
            OrgasmEffect(a);
        GroupFacts f;
        f.victim_hold_scene = OrgasmEngine::IsVictimHoldScene(sid);
        f.lead_count = lead ? OrgasmEngine::GetOrgasmCount(ActorFor(lead)) : 0;
        const bool enabled = EndingEnabled();
        const float hold_max = HoldMaxConfig();
        std::vector<RE::FormID> group;
        for (auto* a : actors)
            group.push_back(a ? a->GetFormID() : 0);
        Work work;
        {
            std::lock_guard lock(g_mutex);
            if (auto* w = FindLocked(ae_id))
                EndingCheckLocked(*w, group, f, work, enabled, hold_max);
        }
        Run(work);
    }

    void OnGatePassed(const std::vector<RE::Actor*>& actors, bool hold_stage)
    {
        if (actors.empty())
            return;
        int ae_id = 0;
        std::int32_t sid = 0;
        {
            std::lock_guard lock(g_mutex);
            auto* w = FindByActorLocked(actors.front()->GetFormID());
            if (!w)
                return;
            ae_id = w->ae_id;
            sid = w->sid;
        }
        std::int64_t mark = -1;
        const auto r = Narration::GatePassed(ae_id, actors, mark);
        const float hold_max = HoldMaxConfig();
        Work work;
        {
            std::lock_guard lock(g_mutex);
            auto* w = FindLocked(ae_id);
            if (!w)
                return;
            webui_log::info("AnimEngineOrgasm: scene {} gate passed [{}] hold {} stage {}/{} narration {}", ae_id,
                Names(actors), hold_stage, w->stage, w->count,
                r == Narration::GateResult::kSent ? "sent" : r == Narration::GateResult::kPending ? "pending" : "none");
            if (r == Narration::GateResult::kNoVoice) {
                // No voice will start: do not hold for one (Engine_GatePassed, orgasm_level below Direct).
                VictimReleaseLocked(*w, work);
                if (hold_stage)
                    AdvanceToFinalLocked(*w, work, hold_max);
                else if (!w->ending_done)
                    ToFinalLocked(*w, work, hold_max);
            } else {
                if (r == Narration::GateResult::kSent)
                    work.push_back([sid, mark]() { OrgasmEngine::GateNarrationSent(sid, mark); });
                w->ending_mark = mark;
                if (hold_stage) {
                    if (w->victim_holding) {
                        // The victim hold already holds this stage: the gate's voice wait takes it over.
                        w->victim_holding = false;
                        SetHold(work, *w, Hold::kVictim, false, -1);
                    }
                    if (!w->gate_holding) {
                        w->gate_holding = true;
                        w->gate_hold_node = w->node;
                        w->gate_held = 0.0;
                        SetHold(work, *w, Hold::kGate, true, w->node);
                    }
                } else {
                    VictimReleaseLocked(*w, work);
                    if (!w->ending_done)
                        ToFinalLocked(*w, work, hold_max);
                }
            }
        }
        Run(work);
    }

    void OnAdvanceToFinal(RE::Actor* actor)
    {
        if (!actor)
            return;
        const float hold_max = HoldMaxConfig();
        Work work;
        {
            std::lock_guard lock(g_mutex);
            auto* w = FindByActorLocked(actor->GetFormID());
            if (!w)
                return;
            AdvanceToFinalLocked(*w, work, hold_max);
        }
        Run(work);
    }

    void OnExhausted(const std::vector<RE::Actor*>& actors)
    {
        if (actors.empty())
            return;
        int ae_id = -1;
        {
            std::lock_guard lock(g_mutex);
            if (auto* w = FindByActorLocked(actors.front()->GetFormID()))
                ae_id = w->ae_id;
        }
        if (ae_id < 0)
            return;
        webui_log::info("AnimEngineOrgasm: scene {} exhausted [{}], ending", ae_id, Names(actors));
        AnimEngine::EndScene(ae_id);
    }

    void Tick(double dt)
    {
        if (dt <= 0.0)
            return;
        struct Probe
        {
            int ae_id;
            std::int32_t sid;
            bool victim;
            bool ending;
            std::int64_t mark;
            std::vector<RE::FormID> actors;
        };
        std::vector<Probe> probes;
        {
            std::lock_guard lock(g_mutex);
            for (const auto& [id, w] : g_wired) {
                if (!w.paused && (w.gate_holding || w.victim_holding || w.ending_holding))
                    probes.push_back({ id, w.sid, w.victim_holding, w.ending_holding, w.ending_mark, w.actors });
            }
        }
        if (probes.empty())
            return;
        // Facts first, outside the lock.
        std::map<int, bool> gate_scene, response_done;
        for (const auto& p : probes) {
            if (p.victim)
                gate_scene[p.ae_id] = OrgasmEngine::IsGateScene(p.sid);
            if (p.ending)
                response_done[p.ae_id] =
                    p.mark >= 0 && NarrationTiming::DoneSinceMostRecentStarted(static_cast<std::uint64_t>(p.mark), p.actors);
        }
        const float wait_max = SexLabNet::GetConfigFloat("sexlab.ending.gate_wait_max", 20.f);
        const float cap = SexLabNet::GetConfigFloat("sexlab.ending.victim_hold_max", 120.f);
        const float hold_max_cfg = HoldMaxConfig();
        Work work;
        {
            std::lock_guard lock(g_mutex);
            for (const auto& p : probes) {
                auto* w = FindLocked(p.ae_id);
                if (!w || w->paused)
                    continue;
                // Gate_Poll: no gate voice by sexlab.ending.gate_wait_max (DN dropped, TTS off): go on anyway.
                if (w->gate_holding) {
                    w->gate_held += dt;
                    if (w->gate_held >= wait_max) {
                        webui_log::info("AnimEngineOrgasm: scene {} no gate voice after {:.0f}s", w->ae_id, w->gate_held);
                        AdvanceToFinalLocked(*w, work, hold_max_cfg);
                    }
                }
                // Victim_Poll: cap sexlab.ending.victim_hold_max (0 = none); a gate scene asks the engine's gate first.
                if (w->victim_holding) {
                    w->victim_held += dt;
                    if (cap > 0.f && w->victim_held >= cap) {
                        const auto gs = gate_scene.find(w->ae_id);
                        const bool is_gate = gs != gate_scene.end() && gs->second;
                        if (is_gate && (!w->victim_expired || w->victim_held < cap + kVictimGateGrace)) {
                            if (!w->victim_expired) {
                                w->victim_expired = true;
                                const auto sid = w->sid;
                                webui_log::info("AnimEngineOrgasm: scene {} no aggressor orgasm after {:.0f}s, asking "
                                                "the gate",
                                    w->ae_id, w->victim_held);
                                work.push_back([sid]() { OrgasmEngine::VictimHoldExpired(sid); });
                            }
                        } else {
                            webui_log::info("AnimEngineOrgasm: scene {} no aggressor orgasm after {:.0f}s, releasing "
                                            "stage {}/{}",
                                w->ae_id, w->victim_held, w->stage, w->count);
                            VictimReleaseLocked(*w, work);
                        }
                    }
                }
                // Ending_Poll: release once the response played, or at the max. AnimEngine's stage clock kept
                // running, so the stage then ends at the later of its timer and the response.
                if (w->ending_holding) {
                    w->ending_held += dt;
                    const float max = EndingHoldMax(*w, hold_max_cfg);
                    const auto rd = response_done.find(w->ae_id);
                    const bool done = rd != response_done.end() && rd->second && w->ending_held >= kEndingMinHold;
                    if (w->ending_held >= max || done) {
                        w->ending_holding = false;
                        SetHold(work, *w, Hold::kEnding, false, -1);
                        webui_log::info("AnimEngineOrgasm: scene {} released final stage after {:.0f}s ({})", w->ae_id,
                            w->ending_held, done ? "response played" : "max");
                    }
                }
            }
        }
        Run(work);
    }

    bool ToggleDeny(RE::Actor* target, RE::Actor* by)
    {
        if (!target)
            return false;
        bool was_denied = false;
        int ae_id = 0;
        {
            std::lock_guard lock(g_mutex);
            auto* w = FindByActorLocked(target->GetFormID());
            if (!w)
                return false;
            ae_id = w->ae_id;
            was_denied = w->denied.erase(target->GetFormID()) > 0;
            if (!was_denied)
                w->denied.insert(target->GetFormID());
        }
        if (was_denied) {
            const bool fired = OrgasmEngine::AllowOrgasm(target, by);
            if (!fired)
                Narration::Allow(target, by);
            webui_log::info("AnimEngineOrgasm: scene {} {} allowed to orgasm by {} fired={}", ae_id,
                NameOf(target->GetFormID()), NameOf(by ? by->GetFormID() : 0), fired);
        } else {
            OrgasmEngine::SetSceneBlocked(target, true);
            Narration::Deny(target, by);
            webui_log::info("AnimEngineOrgasm: scene {} {} denied by {}", ae_id, NameOf(target->GetFormID()),
                NameOf(by ? by->GetFormID() : 0));
        }
        return true;
    }

    std::string DescribeJson(int ae_id)
    {
        std::lock_guard lock(g_mutex);
        const auto* w = FindLocked(ae_id);
        if (!w)
            return "null";
        nlohmann::json j;
        j["sid"] = w->sid;
        j["stage"] = w->stage;
        j["count"] = w->count;
        j["lead"] = std::format("{:08X}", w->lead);
        j["target"] = w->target;
        j["ending_done"] = w->ending_done;
        j["gate_holding"] = w->gate_holding;
        j["victim_holding"] = w->victim_holding;
        j["ending_holding"] = w->ending_holding;
        j["roles"] = w->roles;
        j["denied"] = w->denied.size();
        return SafeDump(j);
    }

    namespace Narration
    {
        // Step 5, orgasm part: Scene.OrgasmMessagesToNarration + NarrateOrgasmStash (orgasm-narration.md), one DN
        // per group. Not yet: the orgasm window / stage fold, DOM melts, the ending hold's response mark.
        // Gate / deny / allow narration stay stubs.
        void OrgasmGroup(int ae_id, const std::vector<RE::Actor*>& actors, const std::vector<std::int32_t>& forced, bool,
            RE::Actor* allower, RE::Actor* allowed, const std::string& extras)
        {
            std::vector<RE::FormID> scene_actors;
            std::unordered_set<RE::FormID> denied;
            bool has_player = false;
            {
                std::lock_guard lock(g_mutex);
                const auto* w = FindLocked(ae_id);
                if (!w)
                    return;
                scene_actors = w->actors;
                denied = w->denied;
                has_player = w->has_player;
            }
            auto* player = RE::PlayerCharacter::GetSingleton();
            const std::string player_name = NameOf(player ? player->GetFormID() : 0);

            std::vector<std::string> forced_n, orgasm_n, again_n, recovering_n;
            RE::Actor* recovering_one = nullptr;
            std::map<int, std::vector<std::string>> denied_n, idle_n; // by band
            for (std::size_t i = 0; i < actors.size(); ++i) {
                if (!actors[i])
                    continue;
                const auto name = NameOf(actors[i]->GetFormID());
                if (i < forced.size() && forced[i] == 1)
                    forced_n.push_back(name);
                else if (OrgasmEngine::GetOrgasmCount(actors[i]) > 1)
                    again_n.push_back(name);
                else
                    orgasm_n.push_back(name);
            }
            for (const auto id : scene_actors) {
                auto* a = ActorFor(id);
                if (!a || std::find(actors.begin(), actors.end(), a) != actors.end())
                    continue;
                const auto name = NameOf(id);
                const int band = EnjoymentBand(OrgasmEngine::GetEnjoyment(a));
                if (denied.contains(id))
                    denied_n[band].push_back(name);
                else if (OrgasmEngine::GetOrgasmCount(a) > 0) {
                    recovering_n.push_back(name);
                    recovering_one = a;
                } else
                    idle_n[band].push_back(name);
            }

            std::string must;
            if (allower && allowed)
                must += NameOf(allower->GetFormID()) + " allowed " + NameOf(allowed->GetFormID()) + " to orgasm. ";
            must += NamesClause(forced_n, "is forced to orgasm by " + player_name + ".",
                "are forced to orgasm by " + player_name + ".");
            must += NamesClause(orgasm_n, "is orgasming.", "are orgasming.");
            must += NamesClause(again_n, "is orgasming. again.", "are orgasming again.");
            for (const auto& [band, names] : denied_n)
                must += BandLeadIn(band) + NamesClause(names, "was denied an orgasm by " + player_name + ".",
                                               "were denied an orgasm by " + player_name + ".");

            std::vector<std::string> parts;
            if (recovering_n.size() == 1)
                parts.push_back(recovering_n[0] + " is recovering from " + PossessivePronoun(recovering_one) + " orgasm. ");
            else if (!recovering_n.empty())
                parts.push_back(NamesClause(recovering_n, "", "are recovering from their orgasms."));
            for (const auto& [band, names] : idle_n)
                parts.push_back(BandLeadIn(band) +
                                NamesClause(names, "is not orgasming right now.", "are not orgasming right now."));
            if (!extras.empty())
                parts.push_back(extras + " ");

            // Budget (sexlab.narration.max_chars): lower-priority parts that do not fit go to the overflow event.
            int budget = SexLabNet::GetConfigInt("sexlab.narration.max_chars", 350);
            if (budget <= 0)
                budget = 350;
            std::string msg = must, overflow;
            for (const auto& p : parts) {
                if (msg.size() + p.size() <= static_cast<std::size_t>(budget))
                    msg += p;
                else
                    overflow += p;
            }
            while (!msg.empty() && msg.back() == ' ')
                msg.pop_back();
            while (!overflow.empty() && overflow.back() == ' ')
                overflow.pop_back();

            RE::Actor* source = actors.front();
            RE::Actor* target = nullptr;
            for (const auto id : scene_actors) {
                if (auto* a = ActorFor(id); a && a != source) {
                    target = a;
                    break;
                }
            }
            webui_log::info("AnimEngineOrgasm: scene {} orgasm narration '{}' overflow {} chars", ae_id, msg,
                overflow.size());
            DispatchShell("NarrateOrgasm",
                RE::MakeFunctionArguments(RE::BSFixedString(msg.c_str()), RE::BSFixedString(overflow.c_str()),
                    static_cast<RE::Actor*>(source), static_cast<RE::Actor*>(target), static_cast<bool>(has_player)));
        }

        GateResult GatePassed(int ae_id, const std::vector<RE::Actor*>& actors, std::int64_t& mark)
        {
            mark = -1;
            webui_log::info("AnimEngineOrgasm: scene {} gate narration deferred (step 5) [{}]", ae_id, Names(actors));
            return GateResult::kNoVoice;
        }

        void Deny(RE::Actor* target, RE::Actor*)
        {
            webui_log::info("AnimEngineOrgasm: deny narration deferred (step 5) {}", NameOf(target ? target->GetFormID() : 0));
        }

        void Allow(RE::Actor* target, RE::Actor*)
        {
            webui_log::info("AnimEngineOrgasm: allow narration deferred (step 5) {}", NameOf(target ? target->GetFormID() : 0));
        }

        bool EndingDialogue()
        {
            return false;
        }
    }
}
