#include "Papyrus_OrgasmEngine.h"

#include "Aid.h"
#include "Config.h"
#include "AnimSpeed.h"
#include "NarrationTiming.h"
#include "OrgasmEngine.h"
#include "WebUI_Log.h"

#include <string>
#include <vector>

namespace PapyrusBindings_OrgasmEngine
{
    namespace
    {
        std::string Str(const RE::BSFixedString& s)
        {
            return s.c_str() ? s.c_str() : "";
        }

        // ---- public API ----
        float GetEnjoyment(RE::StaticFunctionTag*, RE::Actor* a) { return OrgasmEngine::GetEnjoyment(a); }
        void SetEnjoyment(RE::StaticFunctionTag*, RE::Actor* a, float v, RE::BSFixedString src)
        {
            OrgasmEngine::SetEnjoyment(a, v, Str(src));
        }
        void AddEnjoyment(RE::StaticFunctionTag*, RE::Actor* a, float d, RE::BSFixedString src)
        {
            OrgasmEngine::AddEnjoyment(a, d, Str(src));
        }
        bool Arouse(RE::StaticFunctionTag*, RE::Actor* who, RE::Actor* target, float mult)
        {
            return OrgasmEngine::Arouse(who, target, mult);
        }
        bool Calm(RE::StaticFunctionTag*, RE::Actor* who, RE::Actor* target, float mult)
        {
            return OrgasmEngine::Calm(who, target, mult);
        }
        void Edge(RE::StaticFunctionTag*, RE::Actor* a, float seconds, RE::BSFixedString src)
        {
            OrgasmEngine::Edge(a, seconds, Str(src));
        }
        void SetRateModifier(RE::StaticFunctionTag*, RE::Actor* a, RE::BSFixedString src, float mult)
        {
            OrgasmEngine::SetRateModifier(a, Str(src), mult);
        }
        void ClearRateModifier(RE::StaticFunctionTag*, RE::Actor* a, RE::BSFixedString src)
        {
            OrgasmEngine::ClearRateModifier(a, Str(src));
        }
        void SetOrgasmBlocked(RE::StaticFunctionTag*, RE::Actor* a, RE::BSFixedString src, bool blocked)
        {
            OrgasmEngine::SetOrgasmBlocked(a, Str(src), blocked);
        }
        bool IsOrgasmAllowed(RE::StaticFunctionTag*, RE::Actor* a) { return OrgasmEngine::IsOrgasmAllowed(a); }
        void RequestOrgasm(RE::StaticFunctionTag*, RE::Actor* a, bool force, RE::BSFixedString src)
        {
            OrgasmEngine::RequestOrgasm(a, force, Str(src));
        }
        std::int32_t GetOrgasmCount(RE::StaticFunctionTag*, RE::Actor* a) { return OrgasmEngine::GetOrgasmCount(a); }
        float GetSecondsSinceOrgasm(RE::StaticFunctionTag*, RE::Actor* a)
        {
            return OrgasmEngine::GetSecondsSinceOrgasm(a);
        }
        bool IsManaged(RE::StaticFunctionTag*, RE::Actor* a) { return OrgasmEngine::IsManaged(a); }
        bool IsMentallyBroken(RE::StaticFunctionTag*, RE::Actor* a) { return OrgasmEngine::IsMentallyBroken(a); }
        bool IsMiniGameEnabled(RE::StaticFunctionTag*) { return OrgasmEngine::IsMiniGameEnabled(); }
        void SetRates(RE::StaticFunctionTag*, float passive, float aggressor, float victim)
        {
            OrgasmEngine::SetRates(passive, aggressor, victim);
        }

        void ReloadConfig(RE::StaticFunctionTag*) { SexLabNet::Config::GetSingleton().ApplyHudConfig(); }

        // ---- shell (SkyrimNet_SexLab_Scene) ----
        void BeginScene(RE::StaticFunctionTag*, std::int32_t sid, std::vector<RE::Actor*> actors,
            std::vector<std::int32_t> roles, std::vector<float> seeds, bool hasPlayer)
        {
            OrgasmEngine::BeginScene(sid, actors, roles, seeds, hasPlayer);
        }
        void SetStage(RE::StaticFunctionTag*, std::int32_t sid, std::int32_t stage, std::int32_t count)
        {
            OrgasmEngine::SetStage(sid, stage, count);
        }
        void SetStageTimers(RE::StaticFunctionTag*, std::int32_t sid, std::vector<float> secs, bool leadIn)
        {
            OrgasmEngine::SetStageTimers(sid, secs, leadIn);
        }
        void SetScenePaused(RE::StaticFunctionTag*, std::int32_t sid, bool paused)
        {
            OrgasmEngine::SetScenePaused(sid, paused);
        }
        void GateNarrationSent(RE::StaticFunctionTag*, std::int32_t sid, std::int32_t mark)
        {
            OrgasmEngine::GateNarrationSent(sid, mark);
        }
        void SetEndingTarget(RE::StaticFunctionTag*, std::int32_t sid, RE::Actor* lead, std::int32_t target)
        {
            OrgasmEngine::SetEndingTarget(sid, lead, target);
        }
        bool IsGateScene(RE::StaticFunctionTag*, std::int32_t sid) { return OrgasmEngine::IsGateScene(sid); }
        // Response tracking for the final-stage hold, scoped to the scene's actors: mark before sending a
        // narration, then ResponseStartedSince (one of them is speaking) / ResponseDoneSince (that reply ended).
        std::int32_t NarrationMark(RE::StaticFunctionTag*)
        {
            return static_cast<std::int32_t>(NarrationTiming::SpeakerMark());
        }
        bool ResponseStartedSince(RE::StaticFunctionTag*, std::int32_t sid, std::int32_t mark)
        {
            return mark >= 0 && NarrationTiming::StartedSince(static_cast<std::uint64_t>(mark),
                                    OrgasmEngine::SceneActors(sid));
        }
        bool ResponseDoneSince(RE::StaticFunctionTag*, std::int32_t sid, std::int32_t mark)
        {
            return mark >= 0 && NarrationTiming::DoneSinceMostRecentStarted(static_cast<std::uint64_t>(mark),
                                    OrgasmEngine::SceneActors(sid));
        }
        float FinalStageRemaining(RE::StaticFunctionTag*, std::int32_t sid)
        {
            return OrgasmEngine::FinalStageRemaining(sid);
        }
        void SetSceneBlocked(RE::StaticFunctionTag*, RE::Actor* a, bool blocked)
        {
            OrgasmEngine::SetSceneBlocked(a, blocked);
        }
        void SetOrgasmExpected(RE::StaticFunctionTag*, RE::Actor* a, bool expected)
        {
            OrgasmEngine::SetOrgasmExpected(a, expected);
        }
        void SetDomSlave(RE::StaticFunctionTag*, RE::Actor* a, bool dom) { OrgasmEngine::SetDomSlave(a, dom); }
        void SetDomMeter(RE::StaticFunctionTag*, RE::Actor* a, float meter) { OrgasmEngine::SetDomMeter(a, meter); }
        void SetActorSkills(RE::StaticFunctionTag*, RE::Actor* a, std::int32_t skill, std::int32_t lewd)
        {
            OrgasmEngine::SetActorSkills(a, skill, lewd);
        }
        void SetBonusInputs(RE::StaticFunctionTag*, RE::Actor* a, std::vector<float> own, std::vector<float> partner,
            std::int32_t lowestRank, std::int32_t highestRank, std::int32_t actSkill)
        {
            OrgasmEngine::SetBonusInputs(a, own, partner, lowestRank, highestRank, actSkill);
        }
        bool SetStrategy(RE::StaticFunctionTag*, RE::Actor* a, std::int32_t strategy, RE::Actor* target)
        {
            if (strategy < 0 || strategy >= static_cast<std::int32_t>(OrgasmEngine::Strategy::kCount)) {
                return false;
            }
            return OrgasmEngine::SetStrategy(a, static_cast<OrgasmEngine::Strategy>(strategy), target);
        }
        std::int32_t GetStrategy(RE::StaticFunctionTag*, RE::Actor* a)
        {
            return static_cast<std::int32_t>(OrgasmEngine::GetStrategy(a));
        }
        float GetStaminaRegen(RE::StaticFunctionTag*, RE::Actor* a)
        {
            return OrgasmEngine::GetStaminaRegen(a);
        }

        RE::BSFixedString GetStrategyText(RE::StaticFunctionTag*, RE::Actor* a)
        {
            return RE::BSFixedString(OrgasmEngine::GetStrategyText(a).c_str());
        }
        RE::Actor* GetForcedBy(RE::StaticFunctionTag*, RE::Actor* a) { return OrgasmEngine::GetForcedBy(a); }
        void SetForceMethod(RE::StaticFunctionTag*, RE::Actor* a, RE::BSFixedString method)
        {
            OrgasmEngine::SetForceMethod(a, method.c_str() ? method.c_str() : "");
        }
        // ---- LLM actions (SexLab_Aid / SexLab_Force): narration line, "" when refused ----
        RE::BSFixedString AidAction(RE::StaticFunctionTag*, RE::Actor* caster, RE::Actor* target, RE::BSFixedString kind)
        {
            const RE::FormID option = Aid::PickBest(caster, Str(kind));
            if (!option) {
                webui_log::info("Papyrus Aid: {:#x} has no '{}' option", caster ? caster->GetFormID() : 0, Str(kind));
                return "";
            }
            return RE::BSFixedString(Aid::Apply(caster, target, option).c_str());
        }
        RE::BSFixedString ForceAction(RE::StaticFunctionTag*, RE::Actor* forcer, RE::Actor* victim, RE::BSFixedString strategy,
            RE::BSFixedString method)
        {
            if (!victim) {
                return "";
            }
            // The LLM may echo the description ("selfless (please the speaker)"): the first word is the key.
            std::string key = Str(strategy);
            if (const auto cut = key.find_first_of(" (:,"); cut != std::string::npos) {
                key.resize(cut);
            }
            return RE::BSFixedString(OrgasmEngine::Force(forcer, victim->GetFormID(), key, Str(method)).c_str());
        }
        bool HasAidOptions(RE::StaticFunctionTag*, RE::Actor* a) { return ::Aid::HasOptions(a); }
        bool CanForce(RE::StaticFunctionTag*, RE::Actor* a) { return OrgasmEngine::CanForce(a); }
        void EndScene(RE::StaticFunctionTag*, std::int32_t sid) { OrgasmEngine::EndScene(sid); }
        void ResetSpeedScale(RE::StaticFunctionTag*, RE::Actor* a) { OrgasmEngine::ResetSpeedScale(a); }
        std::int32_t GetSpeedLevel(RE::StaticFunctionTag*, RE::Actor* a)
        {
            return OrgasmEngine::NearestSpeedLevel(a ? AnimSpeed::Get(a) : 1.0f);
        }
        bool ConsumeOwnOrgasm(RE::StaticFunctionTag*, RE::Actor* a) { return OrgasmEngine::ConsumeOwnOrgasm(a); }
        std::int32_t NoteExternalOrgasm(RE::StaticFunctionTag*, RE::Actor* a, RE::BSFixedString src)
        {
            return OrgasmEngine::NoteExternalOrgasm(a, Str(src));
        }
        bool AllowOrgasm(RE::StaticFunctionTag*, RE::Actor* a, RE::Actor* allower)
        {
            return OrgasmEngine::AllowOrgasm(a, allower);
        }
    }

    bool Register_OrgasmEngine_Functions(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm) {
            webui_log::error("Couldn't get Papyrus Virtual Machine.");
            return false;
        }
        constexpr std::string_view s = "SkyrimNet_SexLab_OrgasmEngine";

        a_vm->RegisterFunction("GetEnjoyment", s, GetEnjoyment);
        a_vm->RegisterFunction("SetEnjoyment", s, SetEnjoyment);
        a_vm->RegisterFunction("AddEnjoyment", s, AddEnjoyment);
        a_vm->RegisterFunction("Arouse", s, Arouse);
        a_vm->RegisterFunction("Calm", s, Calm);
        a_vm->RegisterFunction("Edge", s, Edge);
        a_vm->RegisterFunction("SetRateModifier", s, SetRateModifier);
        a_vm->RegisterFunction("ClearRateModifier", s, ClearRateModifier);
        a_vm->RegisterFunction("SetOrgasmBlocked", s, SetOrgasmBlocked);
        a_vm->RegisterFunction("IsOrgasmAllowed", s, IsOrgasmAllowed);
        a_vm->RegisterFunction("RequestOrgasm", s, RequestOrgasm);
        a_vm->RegisterFunction("GetOrgasmCount", s, GetOrgasmCount);
        a_vm->RegisterFunction("GetSecondsSinceOrgasm", s, GetSecondsSinceOrgasm);
        a_vm->RegisterFunction("IsManaged", s, IsManaged);
        a_vm->RegisterFunction("IsMentallyBroken", s, IsMentallyBroken);
        a_vm->RegisterFunction("IsMiniGameEnabled", s, IsMiniGameEnabled);
        a_vm->RegisterFunction("SetRates", s, SetRates);
        a_vm->RegisterFunction("ReloadConfig", s, ReloadConfig);

        a_vm->RegisterFunction("BeginScene", s, BeginScene);
        a_vm->RegisterFunction("SetStage", s, SetStage);
        a_vm->RegisterFunction("SetStageTimers", s, SetStageTimers);
        a_vm->RegisterFunction("SetScenePaused", s, SetScenePaused);
        a_vm->RegisterFunction("GateNarrationSent", s, GateNarrationSent);
        a_vm->RegisterFunction("SetEndingTarget", s, SetEndingTarget);
        a_vm->RegisterFunction("IsGateScene", s, IsGateScene);
        a_vm->RegisterFunction("NarrationMark", s, NarrationMark);
        a_vm->RegisterFunction("ResponseStartedSince", s, ResponseStartedSince);
        a_vm->RegisterFunction("ResponseDoneSince", s, ResponseDoneSince);
        a_vm->RegisterFunction("FinalStageRemaining", s, FinalStageRemaining);
        a_vm->RegisterFunction("SetSceneBlocked", s, SetSceneBlocked);
        a_vm->RegisterFunction("SetOrgasmExpected", s, SetOrgasmExpected);
        a_vm->RegisterFunction("SetDomSlave", s, SetDomSlave);
        a_vm->RegisterFunction("SetDomMeter", s, SetDomMeter);
        a_vm->RegisterFunction("SetActorSkills", s, SetActorSkills);
        a_vm->RegisterFunction("SetBonusInputs", s, SetBonusInputs);
        a_vm->RegisterFunction("SetStrategy", s, SetStrategy);
        a_vm->RegisterFunction("GetStrategy", s, GetStrategy);
        a_vm->RegisterFunction("GetStrategyText", s, GetStrategyText);
        a_vm->RegisterFunction("GetStaminaRegen", s, GetStaminaRegen);
        a_vm->RegisterFunction("GetForcedBy", s, GetForcedBy);
        a_vm->RegisterFunction("SetForceMethod", s, SetForceMethod);
        a_vm->RegisterFunction("Aid", s, AidAction);
        a_vm->RegisterFunction("Force", s, ForceAction);
        a_vm->RegisterFunction("HasAidOptions", s, HasAidOptions);
        a_vm->RegisterFunction("CanForce", s, CanForce);
        a_vm->RegisterFunction("EndScene", s, EndScene);
        a_vm->RegisterFunction("ResetSpeedScale", s, ResetSpeedScale);
        a_vm->RegisterFunction("GetSpeedLevel", s, GetSpeedLevel);
        a_vm->RegisterFunction("ConsumeOwnOrgasm", s, ConsumeOwnOrgasm);
        a_vm->RegisterFunction("NoteExternalOrgasm", s, NoteExternalOrgasm);
        a_vm->RegisterFunction("AllowOrgasm", s, AllowOrgasm);

        webui_log::info("Successfully registered Papyrus functions for {}", s);
        return true;
    }
}
