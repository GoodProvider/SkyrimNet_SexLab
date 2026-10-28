#include "Papyrus_AnimEngine.h"

#include "ActorLocker.h"
#include "AnimEngine.h"
#include "AnimationDB.h"
#include "Config.h"
#include "WebUI_Log.h"

#include <algorithm>

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

        bool AnimEngine_Enabled(RE::StaticFunctionTag*)
        {
            return SexLabNet::GetConfigBool("sexlab.anim_engine.enabled", false);
        }

        // Scene creator start: the first registry AnimDB can play with this many actors. Victims play role 2, the
        // others role 1 (no victims: all normal). Returns the scene id, -1 when no registry fits or the start fails.
        std::int32_t AnimEngine_StartFromCreator(RE::StaticFunctionTag*, std::vector<RE::Actor*> actors,
            std::vector<RE::BSFixedString> registries, std::vector<RE::Actor*> victims,
            std::vector<RE::Actor*> no_strip)
        {
            std::erase(actors, nullptr);
            std::erase(victims, nullptr);
            std::erase(no_strip, nullptr);
            std::string tried;
            for (const auto& r : registries) {
                const std::string reg = r.c_str() ? r.c_str() : "";
                if (reg.empty())
                    continue;
                tried += (tried.empty() ? "" : ", ") + reg;
                auto pb = AnimationDB::GetPlayback(reg);
                if (!pb || pb->positions.size() != actors.size())
                    continue;
                const auto ordered = AnimEngine::OrderForRegistry(actors, reg);
                std::vector<std::int32_t> roles;
                if (!victims.empty()) {
                    roles.assign(ordered.size(), 1);
                    for (std::size_t i = 0; i < ordered.size(); ++i) {
                        if (std::ranges::find(victims, ordered[i]) != victims.end())
                            roles[i] = 2;
                    }
                }
                std::vector<bool> strip(ordered.size(), true);
                for (std::size_t i = 0; i < ordered.size(); ++i)
                    strip[i] = std::ranges::find(no_strip, ordered[i]) == no_strip.end();
                // The creator holds the actors' ActorLocker locks (LockAllActorLock); StartScene takes its own. Hand
                // them over, and give them back when the start fails so the SexLab fallback still owns its actors.
                for (auto* a : actors)
                    ActorLocker::Unlock(a);
                const int id = AnimEngine::StartScene(ordered, reg, nullptr, roles, strip);
                if (id < 0) {
                    for (auto* a : actors)
                        ActorLocker::TryLock(a);
                }
                webui_log::info("AnimEngine creator: start '{}' actors={} victims={} no_strip={} -> scene {}", reg,
                    actors.size(), victims.size(), no_strip.size(), id);
                return id;
            }
            webui_log::warn("AnimEngine creator: no playable registry for {} actor(s) among [{}]", actors.size(), tried);
            return -1;
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
        a_vm->RegisterFunction("AnimEngine_Enabled", scriptName, AnimEngine_Enabled, true);
        a_vm->RegisterFunction("AnimEngine_StartFromCreator", scriptName, AnimEngine_StartFromCreator);
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
