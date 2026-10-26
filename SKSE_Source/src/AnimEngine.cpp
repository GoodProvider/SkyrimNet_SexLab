#include "AnimEngine.h"

#include "ActorLocker.h"
#include "AnimEngineOrgasm.h"
#include "AnimationDB.h"
#include "Config.h"
#include "JsonUtil.h"
#include "SceneRegistry.h"
#include "WebUI_Log.h"

#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <map>
#include <mutex>
#include <numbers>
#include <thread>
#include <unordered_set>

namespace AnimEngine
{
    namespace
    {
        using Clock = std::chrono::steady_clock;
        constexpr auto kTickInterval = std::chrono::milliseconds(100);
        constexpr auto kHoldInterval = std::chrono::milliseconds(1000);
        constexpr auto kEventGap = std::chrono::milliseconds(200);
        // A dummy FNIS "s" sequence (FNIS_SexLab_List.txt:8). Entering it leaves the playing sequence, so its S1 can
        // be entered again; SexLab RefreshActor does the same (sslActorAlias.psc:855-862).
        constexpr const char* kSequenceExit = "SexLabSequenceExit1";
        // Re-entries of a position after the graph refused its stage event, before the stage is marked unplayable.
        constexpr int kStageRetries = 2;
        constexpr const char* kShell = "SkyrimNet_SexLab_AnimEngine";
        // SexLab's default stage timers; the last stage (climax) uses the last one.
        constexpr float kDefaultTimers[5] = { 30.f, 20.f, 15.f, 15.f, 9.f };
        // Approach (SexLab PathToCenter, sslActorAlias.psc:537-582): walk when farther than kWalkDist; done on
        // arrival, when PathToReference returns, after kStuckChecks checks without 1 unit of progress, or on timeout.
        constexpr float kWalkDist = 50.f;
        constexpr auto kApproachCheck = std::chrono::milliseconds(1000);
        constexpr auto kApproachTimeout = std::chrono::seconds(30);
        constexpr int kStuckChecks = 4;
        constexpr auto kBeginTimeout = std::chrono::seconds(5);
        // Sheathe (SexLab P+ BeginPlayerSheatheWait, sslThreadModel.psc:938): after the approach, wait for every
        // weapon state to reach kSheathed; re-request for actors still kDrawn; start anyway after the timeout.
        constexpr auto kSheatheRetry = std::chrono::milliseconds(1000);
        constexpr auto kSheatheTimeout = std::chrono::seconds(5);
        // Center heading faces pos 0 toward the others when they are farther than this (else pos 0's own facing).
        constexpr float kFaceMinDist = 10.f;

        enum class Entry { First, Next, Jump };
        enum class Phase { Approach, Sheathe, Begin, Play };

        /// Counts down when a dispatched shell call returns. Atomic, no g_mutex: the VM thread runs it.
        class DoneCallback : public RE::BSScript::IStackCallbackFunctor
        {
        public:
            explicit DoneCallback(std::shared_ptr<std::atomic<int>> left) : left_(std::move(left)) {}
            void operator()(RE::BSScript::Variable) override { --*left_; }
            void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) override {}

        private:
            std::shared_ptr<std::atomic<int>> left_;
        };

        struct PendingEvent
        {
            Clock::time_point due;
            int pos = 0;
            std::string event;
            bool stage = false; // a stage event (false return = unplayable stage)
            int tries = 0;      // re-entries already made for this position and stage
        };

        struct Scene
        {
            int id = 0;
            std::string registry;
            AnimationDB::PlaybackData pb;
            std::vector<RE::FormID> actors;
            std::vector<std::int32_t> roles;              // OrgasmEngine roles per position (empty: all normal)
            float cx = 0.f, cy = 0.f, cz = 0.f, crz = 0.f; // center, rz in radians
            int node = -1;                                // index into pb.nodes
            std::vector<int> history;
            Clock::time_point stage_started;
            float duration = 0.f;
            bool paused = false;
            Clock::time_point paused_at;                  // resume shifts stage_started by the paused time
            std::uint32_t holds = 0;                      // Hold bits; cleared on entering a stage
            bool started = false;
            std::vector<PendingEvent> pending;
            Clock::time_point next_hold;
            std::vector<std::array<float, 4>> placed; // per position x, y, z, az (radians)
            std::unordered_set<std::string> unplayable;
            Phase phase = Phase::Approach;
            int root = 0;
            Clock::time_point phase_started;
            Clock::time_point next_check;
            // Approach, per position: the walk's PathToReference still running (1) or returned (0); null = not walking.
            std::vector<std::shared_ptr<std::atomic<int>>> walking;
            std::vector<float> last_dist;
            std::vector<int> stuck;
            std::shared_ptr<std::atomic<int>> begin_left; // Begin calls not returned yet
        };

        std::mutex g_mutex;
        std::map<int, Scene> g_scenes;
        // Tick's previous run and whether the game was paused then (menus, e.g. the WebUI debug panel).
        Clock::time_point g_last_tick{};
        bool g_game_paused = false;
        int g_next_id = 1;

        bool Enabled()
        {
            return SexLabNet::GetConfigBool("sexlab.anim_engine.enabled", false);
        }

        RE::Actor* ActorOf(RE::FormID id)
        {
            return id ? RE::TESForm::LookupByID<RE::Actor>(id) : nullptr;
        }

        void CallShell(const char* fn, RE::Actor* actor)
        {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm || !actor)
                return;
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> cb;
            auto* args = RE::MakeFunctionArguments(static_cast<RE::Actor*>(actor));
            if (!vm->DispatchStaticCall(RE::BSFixedString(kShell), RE::BSFixedString(fn), args, cb))
                webui_log::warn("AnimEngine: {}.{} dispatch failed", kShell, fn);
        }

        float Degrees(float rad)
        {
            return rad * 180.f / std::numbers::pi_v<float>;
        }

        /// Place / Hold / Begin / LockFace (actor, x, y, z, az degrees). With `left`, it counts down when the call returns.
        bool CallShellPlace(const char* fn, RE::Actor* actor, const std::array<float, 4>& at,
            std::shared_ptr<std::atomic<int>> left = nullptr)
        {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm || !actor)
                return false;
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> cb;
            if (left)
                cb = RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor>{ new DoneCallback(std::move(left)) };
            auto* args = RE::MakeFunctionArguments(static_cast<RE::Actor*>(actor), static_cast<float>(at[0]),
                static_cast<float>(at[1]), static_cast<float>(at[2]), Degrees(at[3]));
            if (!vm->DispatchStaticCall(RE::BSFixedString(kShell), RE::BSFixedString(fn), args, cb)) {
                webui_log::warn("AnimEngine: {}.{} dispatch failed", kShell, fn);
                return false;
            }
            return true;
        }

        /// Approach (actor, face, x, y, z, az degrees); `left` counts down when PathToReference returns.
        bool CallShellApproach(RE::Actor* actor, RE::Actor* face, const std::array<float, 4>& at,
            std::shared_ptr<std::atomic<int>> left)
        {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm || !actor)
                return false;
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> cb{ new DoneCallback(std::move(left)) };
            auto* args = RE::MakeFunctionArguments(static_cast<RE::Actor*>(actor), static_cast<RE::Actor*>(face),
                static_cast<float>(at[0]), static_cast<float>(at[1]), static_cast<float>(at[2]), Degrees(at[3]));
            if (!vm->DispatchStaticCall(RE::BSFixedString(kShell), RE::BSFixedString("Approach"), args, cb)) {
                webui_log::warn("AnimEngine: {}.Approach dispatch failed", kShell);
                return false;
            }
            return true;
        }

        float DistanceTo(RE::Actor* a, const std::array<float, 4>& at)
        {
            return a ? a->GetPosition().GetDistance(RE::NiPoint3{ at[0], at[1], at[2] }) : 0.f;
        }

        RE::WEAPON_STATE WeaponState(RE::Actor* a)
        {
            const auto* state = a ? a->AsActorState() : nullptr;
            return state ? state->GetWeaponState() : RE::WEAPON_STATE::kSheathed;
        }

        void SendModEvent(const char* name, const std::string& str, float num, RE::Actor* sender)
        {
            if (auto* source = SKSE::GetModCallbackEventSource()) {
                SKSE::ModCallbackEvent ev{ name, str.c_str(), num, sender };
                source->SendEvent(&ev);
            }
        }

        const AnimationDB::PlayStage* StageAt(const Scene& s, int pos, int node)
        {
            if (pos < 0 || pos >= static_cast<int>(s.pb.positions.size()))
                return nullptr;
            const auto& st = s.pb.positions[pos].stages;
            return node >= 0 && node < static_cast<int>(st.size()) ? &st[node] : nullptr;
        }

        float StageSeconds(const Scene& s, int node)
        {
            const auto& n = s.pb.nodes[node];
            if (n.timer > 0.f)
                return n.timer;
            if (n.fixed_len > 0.f)
                return n.fixed_len;
            if (n.dest.empty())
                return kDefaultTimers[4];
            return kDefaultTimers[std::min(node, 3)];
        }

        /// Every node's first (only) edge leads to the next node in order, and the last is the sink.
        bool IsLinear(const Scene& s)
        {
            const auto& nodes = s.pb.nodes;
            for (std::size_t i = 0; i < nodes.size(); ++i) {
                const bool last = i + 1 == nodes.size();
                if (last ? !nodes[i].dest.empty() : nodes[i].dest.size() != 1 || nodes[i].dest[0] != nodes[i + 1].id)
                    return false;
            }
            return true;
        }

        /// The node's first-edge chain to a sink (from excluded); stops at a revisit or a bad edge.
        std::vector<int> ChainToSink(const Scene& s, int from)
        {
            std::vector<int> out;
            std::vector<bool> seen(s.pb.nodes.size(), false);
            int cur = from;
            while (cur >= 0 && !seen[cur] && !s.pb.nodes[cur].dest.empty()) {
                seen[cur] = true;
                const int next = s.pb.NodeIndex(s.pb.nodes[cur].dest.front());
                if (next < 0 || seen[next])
                    break;
                out.push_back(next);
                cur = next;
            }
            return out;
        }

        StageView ViewOf(const Scene& s)
        {
            StageView v;
            v.node = s.node;
            if (s.node < 0 || s.pb.nodes.empty())
                return v;
            v.at_sink = s.pb.nodes[s.node].dest.empty();
            v.linear = IsLinear(s);
            std::vector<int> path;
            if (v.linear) {
                for (int i = 0; i < static_cast<int>(s.pb.nodes.size()); ++i)
                    path.push_back(i);
                v.stage = s.node + 1;
            } else {
                path = s.history;
                path.push_back(s.node);
                v.stage = static_cast<int>(path.size());
                const auto chain = ChainToSink(s, s.node);
                path.insert(path.end(), chain.begin(), chain.end());
            }
            v.count = static_cast<int>(path.size());
            for (const int n : path)
                v.secs.push_back(StageSeconds(s, n));
            return v;
        }

        /// The projected final node: the last node of a linear graph, else the first-edge chain's end.
        int FinalNode(const Scene& s)
        {
            if (IsLinear(s))
                return static_cast<int>(s.pb.nodes.size()) - 1;
            const auto chain = ChainToSink(s, s.node);
            return chain.empty() ? s.node : chain.back();
        }

        /// AnimEngineOrgasm notes go out as tasks, never under g_mutex (lock order: the bridge calls back in).
        void NotifyStage(const Scene& s, bool first)
        {
            AnimEngineOrgasm::StageNote note;
            note.epoch = AnimEngineOrgasm::Epoch();
            note.ae_id = s.id;
            note.registry = s.registry;
            note.actors = s.actors;
            note.roles = s.roles;
            note.first = first;
            note.view = ViewOf(s);
            note.node_id = s.pb.nodes[s.node].id;
            SKSE::GetTaskInterface()->AddTask([note = std::move(note)]() { AnimEngineOrgasm::OnStage(note); });
        }

        void NotifyPause(const Scene& s)
        {
            const auto epoch = AnimEngineOrgasm::Epoch();
            const int id = s.id;
            const bool paused = s.paused;
            SKSE::GetTaskInterface()->AddTask([epoch, id, paused]() { AnimEngineOrgasm::OnPause(epoch, id, paused); });
        }

        /// SexLab AE CalcCenterAdjuster (sslBaseAnimation.psc:928-941): −½ × the largest-magnitude forward offset
        /// of the stage, with 2+ actors. SLAL only.
        float CenterAdjust(const Scene& s, int node)
        {
            if (s.pb.format != "slal" || s.actors.size() < 2)
                return 0.f;
            float adj = 0.f;
            for (int p = 0; p < static_cast<int>(s.actors.size()); ++p) {
                if (const auto* st = StageAt(s, p, node); st && std::fabs(st->fwd) > std::fabs(adj))
                    adj = st->fwd;
            }
            return adj * -0.5f;
        }

        /// anim-engine.md §4 (SexLab / P+ OffsetCoords): fwd along the heading, side at heading + 90°.
        std::array<float, 4> Offset(float cx, float cy, float cz, float rz, float fwd, float side, float up, float rot_deg)
        {
            const float sn = std::sin(rz), cs = std::cos(rz);
            float az = rz + rot_deg * std::numbers::pi_v<float> / 180.f;
            const float two_pi = 2.f * std::numbers::pi_v<float>;
            az = std::fmod(az, two_pi);
            if (az < 0.f)
                az += two_pi;
            return { cx + sn * fwd + cs * side, cy + cs * fwd - sn * side, cz + up, az };
        }

        void ComputePlaced(Scene& s, int node)
        {
            const float adj = CenterAdjust(s, node);
            s.placed.assign(s.actors.size(), { 0.f, 0.f, 0.f, 0.f });
            for (int p = 0; p < static_cast<int>(s.actors.size()); ++p) {
                const auto* st = StageAt(s, p, node);
                const float fwd = (st ? st->fwd : 0.f) + adj;
                s.placed[p] = Offset(s.cx, s.cy, s.cz, s.crz, fwd, st ? st->side : 0.f, st ? st->up : 0.f,
                    st ? st->rot : 0.f);
            }
        }

        void PlaceAll(Scene& s, int node)
        {
            ComputePlaced(s, node);
            for (int p = 0; p < static_cast<int>(s.actors.size()); ++p) {
                if (auto* a = ActorOf(s.actors[p]))
                    CallShellPlace("Place", a, s.placed[p]);
            }
            s.next_hold = Clock::now() + kHoldInterval;
        }

        void Queue(Scene& s, Clock::time_point due, int pos, std::string event, bool stage, int tries = 0)
        {
            if (!event.empty())
                s.pending.push_back({ due, pos, std::move(event), stage, tries });
        }

        /// Jump entry for one position: leave the playing FNIS sequence, back to the default state, then the stage
        /// event, with SexLab RefreshActor's timing (sslActorAlias.psc:855-862: exit + default, 0.2 s, S1). The graph
        /// accepts an "s" S1 only from the default state (checkpoints 06-09). FNIS "+" lines are inside an "s"
        /// sequence and must be entered through its first stage. Returns when the stage event is due.
        Clock::time_point QueueReentry(Scene& s, int p, int node, Clock::time_point at, int tries)
        {
            const auto* st = StageAt(s, p, node);
            const auto* root = StageAt(s, p, 0);
            Queue(s, at, p, kSequenceExit, false);
            Queue(s, at, p, "AnimObjectUnequip", false);
            Queue(s, at, p, "IdleForceDefaultState", false);
            auto due = at + kEventGap;
            if (st && st->kind == "+" && root && node != 0) {
                Queue(s, due, p, root->event, true, tries);
                due += kEventGap;
            }
            Queue(s, due, p, st ? st->event : std::string(), true, tries);
            return due;
        }

        /// Jump entry for one position, blending like Next (checkpoint 07). Inside the sequence a "+" event is sent
        /// directly, backward too (as SexLab's sslActorAlias.SendAnimation does). An "s" event is accepted only from the
        /// default state, so it cannot blend: it re-enters through the default state as SexLab does on stage 1
        /// (sslActorAlias.psc:742-745; checkpoint 09). A refused event falls back to QueueReentry in Tick. Returns
        /// when the stage event is due.
        Clock::time_point QueueJump(Scene& s, int p, int from, int node, Clock::time_point at)
        {
            const auto* cur = StageAt(s, p, from);
            const auto* st = StageAt(s, p, node);
            if (!st)
                return at;
            const bool in_seq = cur && (cur->kind == "s" || cur->kind == "+") && !s.unplayable.contains(cur->event);
            if (st->kind == "s" && in_seq) {
                webui_log::debug("AnimEngine: scene {} pos {} jump reenter -> '{}'", s.id, p, st->event);
                return QueueReentry(s, p, node, at, 0);
            }
            if (st->kind == "+" && !in_seq)
                return QueueReentry(s, p, node, at, 0);
            Queue(s, at, p, st->event, true);
            webui_log::debug("AnimEngine: scene {} pos {} jump direct -> '{}'", s.id, p, st->event);
            return at;
        }

        void EnterNode(Scene& s, int node, Entry how)
        {
            const auto now = Clock::now();
            const int from = s.node;
            s.node = node;
            s.pending.clear();
            PlaceAll(s, node);
            auto start = now;
            for (int p = 0; p < static_cast<int>(s.actors.size()); ++p) {
                const auto* st = StageAt(s, p, node);
                const std::string ev = st ? st->event : std::string();
                if (how == Entry::Next) {
                    Queue(s, now, p, ev, true);
                    continue;
                }
                if (how == Entry::Jump) {
                    start = std::max(start, QueueJump(s, p, from, node, now));
                    continue;
                }
                // First: back to the default state, then the stage event.
                Queue(s, now, p, "AnimObjectUnequip", false);
                Queue(s, now, p, "IdleForceDefaultState", false);
                Queue(s, now + kEventGap, p, ev, true);
                start = std::max(start, now + kEventGap);
            }
            for (int p = 0; p < static_cast<int>(s.actors.size()); ++p) {
                if (const auto* st = StageAt(s, p, node); st && (!st->objects.empty() || !st->anim_obj.empty()))
                    webui_log::info("AnimEngine: scene {} pos {} AnimObjects not equipped yet (02): {} {}", s.id, p,
                        st->anim_obj, st->objects.empty() ? "" : st->objects.front());
            }
            s.stage_started = start;
            s.duration = StageSeconds(s, node);
            if (s.paused)
                s.paused_at = start; // paused through the stage change: resume starts this stage's clock
            if (s.holds)
                webui_log::debug("AnimEngine: scene {} holds {:#x} cleared by the stage change", s.id, s.holds);
            s.holds = 0;
            const auto& n = s.pb.nodes[node];
            webui_log::info("AnimEngine: scene {} '{}' stage {}/{} node '{}' ({}) {:.0f}s", s.id, s.registry, n.n,
                s.pb.nodes.size(), n.id, how == Entry::First ? "first" : how == Entry::Next ? "next" : "jump", s.duration);
            SendModEvent("SNSL_AE_StageStart", n.id, static_cast<float>(n.n), ActorOf(s.actors[0]));
            NotifyStage(s, how == Entry::First);
        }

        void EndLocked(std::map<int, Scene>::iterator it, const char* why)
        {
            Scene& s = it->second;
            for (const auto id : s.actors) {
                if (auto* a = ActorOf(id)) {
                    a->NotifyAnimationGraph("AnimObjectUnequip");
                    a->NotifyAnimationGraph("IdleForceDefaultState");
                    CallShell("Unlock", a);
                    ActorLocker::Unlock(a);
                }
            }
            webui_log::info("AnimEngine: scene {} '{}' ended ({})", s.id, s.registry, why);
            SendModEvent("SNSL_AE_SceneEnd", s.registry, static_cast<float>(s.id), ActorOf(s.actors[0]));
            Scenes::Registry::Unregister(Scenes::Registry::Kind::AnimEngine, s.id);
            {
                const auto epoch = AnimEngineOrgasm::Epoch();
                const int id = s.id;
                std::string reason = why;
                SKSE::GetTaskInterface()->AddTask(
                    [epoch, id, reason = std::move(reason)]() { AnimEngineOrgasm::OnEnd(epoch, id, reason); });
            }
            g_scenes.erase(it);
        }

        void AdvanceLocked(std::map<int, Scene>::iterator it)
        {
            Scene& s = it->second;
            const auto& n = s.pb.nodes[s.node];
            if (n.dest.empty()) {
                EndLocked(it, "sink");
                return;
            }
            const int next = s.pb.NodeIndex(n.dest.front());
            if (next < 0) {
                webui_log::warn("AnimEngine: scene {} node '{}' edge to unknown node '{}'", s.id, n.id, n.dest.front());
                EndLocked(it, "bad edge");
                return;
            }
            s.history.push_back(s.node);
            EnterNode(s, next, next == s.node + 1 ? Entry::Next : Entry::Jump);
        }

        std::string Distances(const Scene& s)
        {
            std::string out;
            for (int p = 0; p < static_cast<int>(s.actors.size()) && p < static_cast<int>(s.placed.size()); ++p)
                out += std::format("{}{:.0f}", p ? "," : "", DistanceTo(ActorOf(s.actors[p]), s.placed[p]));
            return out;
        }

        /// Lock + first placement on one Papyrus stack per actor; Tick enters the root node once all have returned.
        void BeginLocked(Scene& s, const char* why)
        {
            const auto now = Clock::now();
            webui_log::info("AnimEngine: scene {} weapons {} ({} ms) d=[{}]", s.id, why,
                std::chrono::duration_cast<std::chrono::milliseconds>(now - s.phase_started).count(), Distances(s));
            s.phase = Phase::Begin;
            s.phase_started = now;
            s.walking.clear();
            s.begin_left = std::make_shared<std::atomic<int>>(static_cast<int>(s.actors.size()));
            for (int p = 0; p < static_cast<int>(s.actors.size()); ++p) {
                auto* a = ActorOf(s.actors[p]);
                if (!a || !CallShellPlace("Begin", a, s.placed[p], s.begin_left))
                    --*s.begin_left;
            }
        }

        /// Positions whose weapon state is not kSheathed (drawing and sheathing included), e.g. "0,1".
        std::string Drawn(const Scene& s)
        {
            std::string out;
            for (int p = 0; p < static_cast<int>(s.actors.size()); ++p) {
                if (WeaponState(ActorOf(s.actors[p])) != RE::WEAPON_STATE::kSheathed)
                    out += std::format("{}{}", out.empty() ? "" : ",", p);
            }
            return out;
        }

        /// Approach done: wait for every weapon to be sheathed before Begin (the first placement). Approach /
        /// LockFace already asked; Tick re-asks actors still kDrawn every kSheatheRetry.
        void SheatheLocked(Scene& s, const char* why)
        {
            const auto now = Clock::now();
            webui_log::info("AnimEngine: scene {} approach done ({}) d=[{}] drawn=[{}]", s.id, why, Distances(s),
                Drawn(s));
            s.phase = Phase::Sheathe;
            s.phase_started = now;
            s.next_check = now + kSheatheRetry;
            s.walking.clear();
        }

        /// Sheathe tick: Begin once nothing is drawn, or on timeout.
        void SheatheTickLocked(Scene& s, Clock::time_point now)
        {
            const std::string drawn = Drawn(s);
            if (drawn.empty()) {
                BeginLocked(s, "sheathed");
                return;
            }
            if (now - s.phase_started >= kSheatheTimeout) {
                webui_log::warn("AnimEngine: scene {} weapons still drawn after {} s for pos [{}]; starting anyway",
                    s.id, kSheatheTimeout.count(), drawn);
                BeginLocked(s, "sheathe timeout");
                return;
            }
            if (now < s.next_check)
                return;
            s.next_check = now + kSheatheRetry;
            for (const auto id : s.actors) {
                if (auto* a = ActorOf(id); a && WeaponState(a) == RE::WEAPON_STATE::kDrawn)
                    CallShell("Sheathe", a);
            }
        }

        /// Approach: actors farther than kWalkDist from their root-node spot walk there; the others lock and wait.
        void StartLocked(Scene& s)
        {
            s.started = true;
            s.root = std::max(0, s.pb.NodeIndex(s.pb.root));
            ComputePlaced(s, s.root);
            const auto now = Clock::now();
            s.phase = Phase::Approach;
            s.phase_started = now;
            s.next_check = now + kApproachCheck;
            const std::size_t n = s.actors.size();
            s.walking.assign(n, nullptr);
            s.last_dist.assign(n, 0.f);
            s.stuck.assign(n, 0);
            const bool walk = SexLabNet::GetConfigBool("sexlab.anim_engine.approach", true);
            int walkers = 0;
            for (std::size_t p = 0; p < n; ++p) {
                auto* a = ActorOf(s.actors[p]);
                if (!a)
                    continue;
                s.last_dist[p] = DistanceTo(a, s.placed[p]);
                if (walk && s.last_dist[p] > kWalkDist) {
                    auto* face = n > 1 ? ActorOf(s.actors[p == 0 ? 1 : 0]) : nullptr;
                    auto left = std::make_shared<std::atomic<int>>(1);
                    if (CallShellApproach(a, face, s.placed[p], left)) {
                        s.walking[p] = left;
                        ++walkers;
                        continue;
                    }
                }
                CallShellPlace("LockFace", a, s.placed[p]); // Lock, then turn toward the partner while they walk up
            }
            webui_log::info("AnimEngine: scene {} started '{}' ({}) actors={} center=({:.0f},{:.0f},{:.0f}) rz={:.1f} "
                            "walking={} d=[{}]",
                s.id, s.registry, s.pb.format, n, s.cx, s.cy, s.cz, Degrees(s.crz), walkers, Distances(s));
            SendModEvent("SNSL_AE_SceneStart", s.registry, static_cast<float>(s.id), ActorOf(s.actors[0]));
            if (walkers == 0)
                SheatheLocked(s, "no walk");
        }

        /// Approach tick: per walker, done when PathToReference returned, within kWalkDist, or stuck.
        void ApproachLocked(Scene& s, Clock::time_point now)
        {
            if (now - s.phase_started >= kApproachTimeout) {
                SheatheLocked(s, "timeout");
                return;
            }
            bool all = true, any_stuck = false;
            for (std::size_t p = 0; p < s.walking.size(); ++p) {
                auto& w = s.walking[p];
                if (!w)
                    continue;
                const float d = DistanceTo(ActorOf(s.actors[p]), s.placed[p]);
                if (*w <= 0 || d <= kWalkDist) {
                    w = nullptr;
                    continue;
                }
                if (now >= s.next_check) {
                    s.stuck[p] = s.last_dist[p] - d < 1.f ? s.stuck[p] + 1 : 0;
                    s.last_dist[p] = d;
                    if (s.stuck[p] >= kStuckChecks) {
                        webui_log::info("AnimEngine: scene {} pos {} stuck at d={:.0f}", s.id, p, d);
                        w = nullptr;
                        any_stuck = true;
                        continue;
                    }
                }
                all = false;
            }
            if (now >= s.next_check)
                s.next_check = now + kApproachCheck;
            if (all)
                SheatheLocked(s, any_stuck ? "stuck" : "arrived");
        }

        void Tick()
        {
            std::lock_guard lock(g_mutex);
            const auto now = Clock::now();
            const auto dt = g_last_tick == Clock::time_point{} ? Clock::duration::zero() : now - g_last_tick;
            g_last_tick = now;
            // A paused game does not update the behavior graph: an event that needs the previous one applied (S1
            // after the exit sequence) is refused (checkpoint 08). Freeze the queue and the stage timer until unpause.
            auto* ui = RE::UI::GetSingleton();
            const bool game_paused = ui && ui->GameIsPaused();
            if (game_paused != g_game_paused) {
                g_game_paused = game_paused;
                if (!g_scenes.empty())
                    webui_log::debug("AnimEngine: game {}; event queue {}", game_paused ? "paused" : "unpaused",
                        game_paused ? "frozen" : "resumed");
            }
            for (auto it = g_scenes.begin(); it != g_scenes.end();) {
                auto cur = it++;
                Scene& s = cur->second;
                if (!s.started)
                    continue;
                if (game_paused && s.phase == Phase::Play) {
                    for (auto& e : s.pending)
                        e.due += dt;
                    s.stage_started += dt;
                    if (s.paused)
                        s.paused_at += dt;
                    continue;
                }
                bool gone = false;
                for (const auto id : s.actors) {
                    auto* a = ActorOf(id);
                    if (!a || a->IsDead() || !a->Is3DLoaded()) {
                        gone = true;
                        break;
                    }
                }
                if (gone) {
                    EndLocked(cur, "actor unloaded or dead");
                    continue;
                }
                if (s.phase == Phase::Approach) {
                    ApproachLocked(s, now);
                    continue;
                }
                if (s.phase == Phase::Sheathe) {
                    SheatheTickLocked(s, now);
                    continue;
                }
                if (s.phase == Phase::Begin) {
                    const bool timeout = now - s.phase_started >= kBeginTimeout;
                    if (*s.begin_left > 0 && !timeout)
                        continue;
                    if (timeout && *s.begin_left > 0)
                        webui_log::warn("AnimEngine: scene {} Begin did not return for {} actor(s); starting anyway",
                            s.id, s.begin_left->load());
                    s.phase = Phase::Play;
                    EnterNode(s, s.root, Entry::First);
                    continue;
                }
                // Due events, in order. A refused stage event re-enters that position (after the loop).
                std::vector<std::pair<int, int>> reenter; // pos, tries
                for (std::size_t i = 0; i < s.pending.size();) {
                    if (s.pending[i].due > now) {
                        ++i;
                        continue;
                    }
                    const PendingEvent ev = s.pending[i];
                    s.pending.erase(s.pending.begin() + static_cast<std::ptrdiff_t>(i));
                    auto* a = ActorOf(s.actors[ev.pos]);
                    const bool ok = a && a->NotifyAnimationGraph(RE::BSFixedString(ev.event));
                    if (!ev.stage && !ok)
                        webui_log::debug("AnimEngine: scene {} pos {} '{}' (control) refused", s.id, ev.pos, ev.event);
                    if (ev.stage) {
                        if (ok)
                            webui_log::debug("AnimEngine: scene {} pos {} '{}' ok", s.id, ev.pos, ev.event);
                        else if (ev.tries < kStageRetries && !s.unplayable.contains(ev.event)) {
                            if (std::none_of(reenter.begin(), reenter.end(), [&](auto& r) { return r.first == ev.pos; })) {
                                webui_log::warn("AnimEngine: scene {} pos {} '{}' refused; re-entering (try {})", s.id,
                                    ev.pos, ev.event, ev.tries + 1);
                                reenter.emplace_back(ev.pos, ev.tries + 1);
                            }
                        } else if (s.unplayable.insert(ev.event).second)
                            webui_log::warn("AnimEngine: scene {} pos {} stage event '{}' refused by the behavior graph "
                                            "(unplayable: no FNIS/Pandora event for this actor)",
                                s.id, ev.pos, ev.event);
                    }
                }
                for (const auto& [pos, tries] : reenter) {
                    std::erase_if(s.pending, [pos](const PendingEvent& e) { return e.pos == pos; });
                    s.stage_started = std::max(s.stage_started, QueueReentry(s, pos, s.node, now + kEventGap, tries));
                }
                if (now >= s.next_hold) {
                    s.next_hold = now + kHoldInterval;
                    for (int p = 0; p < static_cast<int>(s.actors.size()) && p < static_cast<int>(s.placed.size()); ++p) {
                        if (auto* a = ActorOf(s.actors[p]))
                            CallShellPlace("Hold", a, s.placed[p]);
                    }
                }
                if (!s.paused && s.holds == 0 && s.pending.empty() && now >= s.stage_started &&
                    std::chrono::duration<float>(now - s.stage_started).count() >= s.duration)
                    AdvanceLocked(cur);
            }
        }

        bool IsCreature(RE::Actor* a)
        {
            return a && !a->HasKeywordString("ActorTypeNPC");
        }

        int GenderClass(RE::Actor* a)
        {
            if (IsCreature(a))
                return 2;
            auto* base = a ? a->GetActorBase() : nullptr;
            return base && base->GetSex() == RE::SEX::kFemale ? 1 : 0;
        }

        /// Runs f on the main thread; stage commands (playing_only) wait for Phase::Play, End works in any phase.
        template <class F>
        bool WithScene(int scene_id, F&& f, bool playing_only = true)
        {
            {
                std::lock_guard lock(g_mutex);
                if (!g_scenes.contains(scene_id))
                    return false;
            }
            SKSE::GetTaskInterface()->AddTask([scene_id, playing_only, f = std::forward<F>(f)]() mutable {
                std::lock_guard lock(g_mutex);
                auto it = g_scenes.find(scene_id);
                if (it != g_scenes.end() && it->second.started && (!playing_only || it->second.phase == Phase::Play))
                    f(it);
            });
            return true;
        }
    }

    int StartScene(const std::vector<RE::Actor*>& actors, const std::string& registry, RE::TESObjectREFR* center,
        const std::vector<std::int32_t>& roles)
    {
        if (!Enabled()) {
            webui_log::warn("AnimEngine: StartScene '{}' refused: sexlab.anim_engine.enabled is off", registry);
            return -1;
        }
        auto pb = AnimationDB::GetPlayback(registry);
        if (!pb || pb->nodes.empty()) {
            webui_log::warn("AnimEngine: StartScene: no playback data for '{}'", registry);
            return -1;
        }
        if (actors.size() != pb->positions.size() || actors.empty()) {
            webui_log::warn("AnimEngine: StartScene '{}' needs {} actors, got {}", registry, pb->positions.size(),
                actors.size());
            return -1;
        }
        std::vector<RE::Actor*> locked;
        for (auto* a : actors) {
            if (!a || SceneOf(a) >= 0 || !ActorLocker::TryLock(a)) {
                webui_log::warn("AnimEngine: StartScene '{}': actor {:08X} is busy or invalid", registry,
                    a ? a->GetFormID() : 0);
                for (auto* l : locked)
                    ActorLocker::Unlock(l);
                return -1;
            }
            locked.push_back(a);
        }
        Scene s;
        s.registry = registry;
        s.pb = std::move(*pb);
        for (auto* a : actors)
            s.actors.push_back(a->GetFormID());
        if (roles.size() == actors.size())
            s.roles = roles;
        RE::TESObjectREFR* c = center ? center : actors.front();
        const auto pos = c->GetPosition();
        s.cx = pos.x;
        s.cy = pos.y;
        s.cz = pos.z;
        s.crz = c->GetAngleZ();
        // No explicit center: face pos 0 toward the others, so the actors turn to face each other, not pos 0's facing.
        if (!center && actors.size() > 1) {
            float mx = 0.f, my = 0.f;
            for (std::size_t i = 1; i < actors.size(); ++i) {
                const auto p = actors[i]->GetPosition();
                mx += p.x;
                my += p.y;
            }
            const float n = static_cast<float>(actors.size() - 1);
            const float dx = mx / n - s.cx, dy = my / n - s.cy;
            if (dx * dx + dy * dy > kFaceMinDist * kFaceMinDist) {
                s.crz = std::atan2(dx, dy);
                if (s.crz < 0.f)
                    s.crz += 2.f * std::numbers::pi_v<float>;
            }
        }
        // SLSB scene furniture offset moves the center (same rotation math).
        const auto& fo = s.pb.furniture_offset;
        if (fo[0] != 0.f || fo[1] != 0.f || fo[2] != 0.f || fo[3] != 0.f) {
            const auto at = Offset(s.cx, s.cy, s.cz, s.crz, fo[0], fo[1], fo[2], fo[3]);
            s.cx = at[0];
            s.cy = at[1];
            s.cz = at[2];
            s.crz = at[3];
        }
        int id = 0;
        {
            std::lock_guard lock(g_mutex);
            id = g_next_id++;
            s.id = id;
            Scenes::Registry::Register(Scenes::Registry::Kind::AnimEngine, id, s.actors);
            g_scenes.emplace(id, std::move(s));
        }
        SKSE::GetTaskInterface()->AddTask([id]() {
            std::lock_guard lock(g_mutex);
            auto it = g_scenes.find(id);
            if (it != g_scenes.end())
                StartLocked(it->second);
        });
        return id;
    }

    bool Advance(int scene_id)
    {
        return WithScene(scene_id, [](auto it) { AdvanceLocked(it); });
    }

    bool GoToNode(int scene_id, const std::string& node_id)
    {
        return WithScene(scene_id, [node_id](auto it) {
            Scene& s = it->second;
            const int idx = s.pb.NodeIndex(node_id);
            if (idx < 0) {
                webui_log::warn("AnimEngine: scene {} has no node '{}'", s.id, node_id);
                return;
            }
            s.history.push_back(s.node);
            EnterNode(s, idx, idx == s.node + 1 ? Entry::Next : Entry::Jump);
        });
    }

    bool Back(int scene_id)
    {
        return WithScene(scene_id, [](auto it) {
            Scene& s = it->second;
            if (s.history.empty())
                return;
            const int prev = s.history.back();
            s.history.pop_back();
            EnterNode(s, prev, Entry::Jump);
        });
    }

    bool GoToFinal(int scene_id)
    {
        return WithScene(scene_id, [](auto it) {
            Scene& s = it->second;
            const int idx = FinalNode(s);
            if (idx == s.node) {
                webui_log::debug("AnimEngine: scene {} GoToFinal: already at the final stage", s.id);
                return;
            }
            webui_log::info("AnimEngine: scene {} final stage '{}' -> '{}'", s.id, s.pb.nodes[s.node].id,
                s.pb.nodes[idx].id);
            s.history.push_back(s.node);
            EnterNode(s, idx, idx == s.node + 1 ? Entry::Next : Entry::Jump);
        });
    }

    bool EndScene(int scene_id)
    {
        return WithScene(scene_id, [](auto it) { EndLocked(it, "requested"); }, false);
    }

    namespace
    {
        /// Pause keeps the stage's elapsed time: resume shifts stage_started by the time paused.
        void SetPausedLocked(Scene& s, bool paused)
        {
            if (s.paused == paused)
                return;
            const auto now = Clock::now();
            s.paused = paused;
            if (paused)
                s.paused_at = now;
            else if (now > s.paused_at)
                s.stage_started += now - s.paused_at;
            webui_log::info("AnimEngine: scene {} {} (stage elapsed {:.1f}s of {:.0f}s)", s.id,
                paused ? "paused" : "resumed",
                std::chrono::duration<float>((paused ? now : Clock::now()) - s.stage_started).count(), s.duration);
            NotifyPause(s);
        }
    }

    bool SetPaused(int scene_id, bool paused)
    {
        return WithScene(scene_id, [paused](auto it) { SetPausedLocked(it->second, paused); });
    }

    bool TogglePaused(int scene_id)
    {
        return WithScene(scene_id, [](auto it) { SetPausedLocked(it->second, !it->second.paused); });
    }

    bool SetHold(int scene_id, Hold hold, bool on, int node)
    {
        return WithScene(scene_id, [hold, on, node](auto it) {
            Scene& s = it->second;
            if (node >= 0 && s.node != node) {
                webui_log::debug("AnimEngine: scene {} hold {:#x} {} skipped: stage moved", s.id,
                    static_cast<std::uint32_t>(hold), on ? "on" : "off");
                return;
            }
            const auto bit = static_cast<std::uint32_t>(hold);
            const auto before = s.holds;
            s.holds = on ? (s.holds | bit) : (s.holds & ~bit);
            if (s.holds != before)
                webui_log::info("AnimEngine: scene {} hold {} {} (holds {:#x})", s.id,
                    hold == Hold::kGate ? "gate" : hold == Hold::kVictim ? "victim" : "ending", on ? "on" : "off",
                    s.holds);
        });
    }

    int SceneOf(RE::Actor* actor)
    {
        if (!actor)
            return -1;
        std::lock_guard lock(g_mutex);
        for (const auto& [id, s] : g_scenes) {
            if (std::find(s.actors.begin(), s.actors.end(), actor->GetFormID()) != s.actors.end())
                return id;
        }
        return -1;
    }

    int LatestScene()
    {
        std::lock_guard lock(g_mutex);
        return g_scenes.empty() ? -1 : g_scenes.rbegin()->first;
    }

    std::string DescribeJson(int scene_id)
    {
        std::lock_guard lock(g_mutex);
        auto it = g_scenes.find(scene_id);
        if (it == g_scenes.end())
            return {};
        const Scene& s = it->second;
        nlohmann::json j;
        j["id"] = s.id;
        j["registry"] = s.registry;
        j["format"] = s.pb.format;
        j["stage_count"] = s.pb.nodes.size();
        if (s.node >= 0) {
            j["node"] = s.pb.nodes[s.node].id;
            j["stage"] = s.pb.nodes[s.node].n;
            j["sink"] = s.pb.nodes[s.node].dest.empty();
        }
        j["phase"] = s.phase == Phase::Approach ? "approach"
                     : s.phase == Phase::Sheathe ? "sheathe"
                     : s.phase == Phase::Begin   ? "begin"
                                                 : "play";
        j["paused"] = s.paused;
        j["holds"] = s.holds;
        j["duration"] = s.duration;
        j["elapsed"] = std::chrono::duration<float>((s.paused ? s.paused_at : Clock::now()) - s.stage_started).count();
        if (s.node >= 0) {
            const auto v = ViewOf(s);
            j["engine_stage"] = v.stage;
            j["engine_count"] = v.count;
            j["linear"] = v.linear;
        }
        std::vector<std::string> hist;
        for (const int h : s.history)
            hist.push_back(s.pb.nodes[h].id);
        j["history"] = hist;
        std::vector<std::string> acts;
        for (const auto id : s.actors)
            acts.push_back(std::format("{:08X}", id));
        j["actors"] = acts;
        j["unplayable"] = std::vector<std::string>(s.unplayable.begin(), s.unplayable.end());
        j["orgasm_engine"] = nlohmann::json::parse(AnimEngineOrgasm::DescribeJson(s.id), nullptr, false);
        return SafeDump(j);
    }

    std::vector<RE::Actor*> OrderForRegistry(const std::vector<RE::Actor*>& actors, const std::string& registry)
    {
        auto pb = AnimationDB::GetPlayback(registry);
        if (!pb || pb->positions.size() != actors.size())
            return actors;
        std::vector<RE::Actor*> out;
        std::vector<bool> used(actors.size(), false);
        for (const auto& pos : pb->positions) {
            const int want = pos.gender >= 2 ? 2 : pos.gender;
            int pick = -1;
            for (std::size_t i = 0; i < actors.size() && pick < 0; ++i) {
                if (!used[i] && GenderClass(actors[i]) == want)
                    pick = static_cast<int>(i);
            }
            for (std::size_t i = 0; i < actors.size() && pick < 0; ++i) {
                if (!used[i])
                    pick = static_cast<int>(i);
            }
            used[pick] = true;
            out.push_back(actors[pick]);
        }
        return out;
    }

    void Install()
    {
        static std::once_flag once;
        std::call_once(once, []() {
            std::thread([]() {
                while (true) {
                    std::this_thread::sleep_for(kTickInterval);
                    bool any = false;
                    {
                        std::lock_guard lock(g_mutex);
                        any = !g_scenes.empty();
                    }
                    if (any) {
                        if (auto* tasks = SKSE::GetTaskInterface())
                            tasks->AddTask([]() { Tick(); });
                    }
                }
            }).detach();
            webui_log::info("AnimEngine: tick installed ({} ms)", kTickInterval.count());
        });
    }

    void ClearAll()
    {
        std::lock_guard lock(g_mutex);
        if (!g_scenes.empty())
            webui_log::info("AnimEngine: cleared {} scene(s)", g_scenes.size());
        Scenes::Registry::ClearKind(Scenes::Registry::Kind::AnimEngine);
        g_scenes.clear();
        AnimEngineOrgasm::Clear(); // leaf lock; drops notes still queued for the old scenes (epoch)
    }

    void Save(SKSE::SerializationInterface* intfc)
    {
        std::lock_guard lock(g_mutex);
        std::vector<RE::FormID> ids;
        for (const auto& [id, s] : g_scenes)
            ids.insert(ids.end(), s.actors.begin(), s.actors.end());
        if (!intfc->OpenRecord(kRecord, kRecordVersion)) {
            webui_log::error("AnimEngine: failed to open co-save record");
            return;
        }
        intfc->WriteRecordData(static_cast<std::uint32_t>(ids.size()));
        for (const auto id : ids)
            intfc->WriteRecordData(id);
    }

    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t)
    {
        ClearAll();
        if (version != kRecordVersion)
            return;
        std::uint32_t n = 0;
        if (!intfc->ReadRecordData(n))
            return;
        // Scenes never survive a load: release the actors the save caught mid-scene (restraint, vehicle, controls).
        std::vector<RE::FormID> ids;
        for (std::uint32_t i = 0; i < n; ++i) {
            RE::FormID oldId = 0, newId = 0;
            if (!intfc->ReadRecordData(oldId))
                break;
            if (intfc->ResolveFormID(oldId, newId))
                ids.push_back(newId);
        }
        if (ids.empty())
            return;
        SKSE::GetTaskInterface()->AddTask([ids]() {
            for (const auto id : ids) {
                if (auto* a = ActorOf(id)) {
                    a->NotifyAnimationGraph("IdleForceDefaultState");
                    CallShell("Unlock", a);
                }
            }
        });
        webui_log::info("AnimEngine: releasing {} actor(s) saved mid-scene", ids.size());
    }

    void Revert()
    {
        ClearAll();
    }
}
