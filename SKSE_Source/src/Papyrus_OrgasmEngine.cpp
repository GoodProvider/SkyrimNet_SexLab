#include "Papyrus_OrgasmEngine.h"

#include "Config.h"
#include "AnimSpeed.h"
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
        void GateNarrationSent(RE::StaticFunctionTag*, std::int32_t sid)
        {
            OrgasmEngine::GateNarrationSent(sid);
        }
        void SetEndingTarget(RE::StaticFunctionTag*, std::int32_t sid, RE::Actor* lead, std::int32_t target)
        {
            OrgasmEngine::SetEndingTarget(sid, lead, target);
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
        a_vm->RegisterFunction("FinalStageRemaining", s, FinalStageRemaining);
        a_vm->RegisterFunction("SetSceneBlocked", s, SetSceneBlocked);
        a_vm->RegisterFunction("SetOrgasmExpected", s, SetOrgasmExpected);
        a_vm->RegisterFunction("SetDomSlave", s, SetDomSlave);
        a_vm->RegisterFunction("SetDomMeter", s, SetDomMeter);
        a_vm->RegisterFunction("SetActorSkills", s, SetActorSkills);
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
