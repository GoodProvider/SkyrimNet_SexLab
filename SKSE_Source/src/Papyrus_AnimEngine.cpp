#include "Papyrus_AnimEngine.h"

#include "AnimEngine.h"
#include "WebUI_Log.h"

namespace PapyrusBindings_AnimEngine
{
    namespace
    {
        int Resolve(std::int32_t scene_id)
        {
            return scene_id < 0 ? AnimEngine::LatestScene() : scene_id;
        }

        // Debug start: one animation, the given actors ordered by the registry's position genders (b may be None
        // for a solo animation). Returns the scene id, -1 on failure.
        std::int32_t AnimEngine_DebugStart(RE::StaticFunctionTag*, RE::Actor* a, RE::Actor* b, RE::BSFixedString registry)
        {
            std::vector<RE::Actor*> actors;
            if (a)
                actors.push_back(a);
            if (b)
                actors.push_back(b);
            const std::string reg = registry.c_str() ? registry.c_str() : "";
            return AnimEngine::StartScene(AnimEngine::OrderForRegistry(actors, reg), reg, nullptr);
        }

        // scene_id -1 = the newest scene.
        bool AnimEngine_Advance(RE::StaticFunctionTag*, std::int32_t scene_id)
        {
            return AnimEngine::Advance(Resolve(scene_id));
        }

        bool AnimEngine_Back(RE::StaticFunctionTag*, std::int32_t scene_id)
        {
            return AnimEngine::Back(Resolve(scene_id));
        }

        bool AnimEngine_GoToNode(RE::StaticFunctionTag*, std::int32_t scene_id, RE::BSFixedString node)
        {
            return AnimEngine::GoToNode(Resolve(scene_id), node.c_str() ? node.c_str() : "");
        }

        bool AnimEngine_SetPaused(RE::StaticFunctionTag*, std::int32_t scene_id, bool paused)
        {
            return AnimEngine::SetPaused(Resolve(scene_id), paused);
        }

        bool AnimEngine_End(RE::StaticFunctionTag*, std::int32_t scene_id)
        {
            return AnimEngine::EndScene(Resolve(scene_id));
        }

        std::int32_t AnimEngine_SceneOf(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return AnimEngine::SceneOf(actor);
        }

        RE::BSFixedString AnimEngine_Describe(RE::StaticFunctionTag*, std::int32_t scene_id)
        {
            return RE::BSFixedString(AnimEngine::DescribeJson(Resolve(scene_id)));
        }
    }

    bool Register_AnimEngine_Functions(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm)
            return false;
        constexpr std::string_view scriptName = "SkyrimNet_SexLab_AnimEngine";
        a_vm->RegisterFunction("AnimEngine_DebugStart", scriptName, AnimEngine_DebugStart);
        a_vm->RegisterFunction("AnimEngine_Advance", scriptName, AnimEngine_Advance);
        a_vm->RegisterFunction("AnimEngine_Back", scriptName, AnimEngine_Back);
        a_vm->RegisterFunction("AnimEngine_GoToNode", scriptName, AnimEngine_GoToNode);
        a_vm->RegisterFunction("AnimEngine_SetPaused", scriptName, AnimEngine_SetPaused);
        a_vm->RegisterFunction("AnimEngine_End", scriptName, AnimEngine_End);
        a_vm->RegisterFunction("AnimEngine_SceneOf", scriptName, AnimEngine_SceneOf, true);
        a_vm->RegisterFunction("AnimEngine_Describe", scriptName, AnimEngine_Describe, true);
        return true;
    }
}
