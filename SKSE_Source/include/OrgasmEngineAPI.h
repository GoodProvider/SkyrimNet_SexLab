/*
 * SkyrimNet_SexLab OrgasmEngine — public C++ API.
 *
 * For modders: copy this file into your own SKSE plugin. It has no dependency on SkyrimNet_SexLab's
 * internal headers; RE::Actor comes from your CommonLibSSE(-NG) build.
 *
 *   #include "OrgasmEngineAPI.h"
 *   // at or after SKSE kPostLoad:
 *   auto* engine = SKYRIMNET_SEXLAB_API::RequestOrgasmEngine();
 *   if (engine) engine->AddEnjoyment(actor, 5.0f, "my_plugin");
 *
 * Every call is thread-safe. Event callbacks run on the game's main thread.
 * `source` is a free-form owner id ("dom", "dd_vibrator", ...). Blocks and rate modifiers are keyed
 * by it, so two plugins never clear each other's state.
 */
#pragma once

#ifndef WIN32_LEAN_AND_MEAN
    #define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
    #define NOMINMAX
#endif

#include <Windows.h>
#include <cstdint>

namespace RE
{
    class Actor;
}

namespace SKYRIMNET_SEXLAB_API
{
    constexpr const wchar_t* PluginDll = L"SkyrimNet_SexLab.dll";
    constexpr const char* RequestFunctionName = "RequestOrgasmEngineAPI";

    enum class InterfaceVersion : std::uint32_t
    {
        V1 = 1,
        V2 = 2,  // + mini-game NPC strategies (IOrgasmEngineV2)
    };

    enum class EngineEventType : std::uint32_t
    {
        kOrgasm = 0,       // target orgasmed; count = its orgasm total this scene
        kOrgasmDenied = 1, // target reached the orgasm test but a block stopped it
        kEdge = 2,         // source calmed target at >= 90 enjoyment; value = edge seconds
        kMentalBreak = 3,  // target's mental break changed; count = 1 broken, 0 recovered
    };

    struct EngineEvent
    {
        EngineEventType type;
        RE::Actor* target;     // actor the event is about
        RE::Actor* source;     // acting actor (may be nullptr, or equal target)
        const char* sourceId;  // owner id of the change ("minigame", "final_stage", "webui", ...)
        float value;
        std::int32_t count;
    };

    using EngineEventCallback = void (*)(const EngineEvent& a_event);

    class IOrgasmEngineV1
    {
    protected:
        ~IOrgasmEngineV1() = default;

    public:
        /// Our enjoyment (0-100). 0 when the actor is not in a managed scene.
        virtual float GetEnjoyment(RE::Actor* a_actor) noexcept = 0;
        virtual void SetEnjoyment(RE::Actor* a_actor, float a_value, const char* a_source) noexcept = 0;
        virtual void AddEnjoyment(RE::Actor* a_actor, float a_delta, const char* a_source) noexcept = 0;

        /// Mini-game actions (skill, cost, edge, mental break and narration included).
        /// False when `who` cannot pay the cost, is mentally broken (calm), or target is not managed.
        virtual bool Arouse(RE::Actor* a_who, RE::Actor* a_target, float a_mult) noexcept = 0;
        virtual bool Calm(RE::Actor* a_who, RE::Actor* a_target, float a_mult) noexcept = 0;

        /// Holds off the orgasm test for `seconds`.
        virtual void Edge(RE::Actor* a_actor, float a_seconds, const char* a_source) noexcept = 0;

        /// Multiplies the passive gain. Modifiers from different sources multiply together.
        virtual void SetRateModifier(RE::Actor* a_actor, const char* a_source, float a_mult) noexcept = 0;
        virtual void ClearRateModifier(RE::Actor* a_actor, const char* a_source) noexcept = 0;

        /// Any source blocking stops the automatic orgasm (a forced request still fires).
        virtual void SetOrgasmBlocked(RE::Actor* a_actor, const char* a_source, bool a_blocked) noexcept = 0;
        virtual bool IsOrgasmAllowed(RE::Actor* a_actor) noexcept = 0;

        /// Queue an orgasm for the next tick. force = skip every gate.
        virtual void RequestOrgasm(RE::Actor* a_actor, bool a_force, const char* a_source) noexcept = 0;

        virtual std::int32_t GetOrgasmCount(RE::Actor* a_actor) noexcept = 0;
        /// Seconds since the last orgasm; -1 when none this scene.
        virtual float GetSecondsSinceOrgasm(RE::Actor* a_actor) noexcept = 0;
        virtual bool IsManaged(RE::Actor* a_actor) noexcept = 0;
        virtual bool IsMentallyBroken(RE::Actor* a_actor) noexcept = 0;

        /// Runtime override of the role multipliers (normal / aggressor / victim) on the scene's
        /// stage-timer base rate (1.0 reaches 100 near the end of a normal scene).
        /// A config save restores the dashboard values.
        virtual void SetRates(float a_passive, float a_aggressor, float a_victim) noexcept = 0;

        /// Returns a handle for UnregisterEventCallback (0 on failure).
        virtual std::uint32_t RegisterEventCallback(EngineEventCallback a_callback) noexcept = 0;
        virtual void UnregisterEventCallback(std::uint32_t a_handle) noexcept = 0;
    };

    /// Mini-game NPC strategy ids (same as the Papyrus SetStrategy ids).
    enum class Strategy : std::int32_t
    {
        kPassive = 0,
        kMutual = 1,
        kSelfish = 2,
        kSelfless = 3,
        kTogether = 4,
        kTease = 5,
        kReject = 6,
        kCumQuick = 7,
        kGreedy = 8,
        kForcedOrgasm = 9,
        kAcceptForce = 10,
    };

    class IOrgasmEngineV2 : public IOrgasmEngineV1
    {
    protected:
        ~IOrgasmEngineV2() = default;

    public:
        /// Multi-Orgasm Mini-game mode only: the engine plays the mini-game for the NPC with this strategy.
        /// a_target: Tease / Greedy (a victim) / ForcedOrgasm; nullptr picks one. False when not allowed.
        virtual bool SetStrategy(RE::Actor* a_actor, Strategy a_strategy, RE::Actor* a_target) noexcept = 0;
        virtual Strategy GetStrategy(RE::Actor* a_actor) noexcept = 0;
    };

    using RequestOrgasmEngineAPIFunc = void* (*)(InterfaceVersion a_version);

    /// Consumer helper. Call at or after SKSE kPostLoad. nullptr when SkyrimNet_SexLab is not loaded.
    [[nodiscard]] inline IOrgasmEngineV1* RequestOrgasmEngine()
    {
        const auto module = GetModuleHandleW(PluginDll);
        if (!module) {
            return nullptr;
        }
        const auto fn = reinterpret_cast<RequestOrgasmEngineAPIFunc>(GetProcAddress(module, RequestFunctionName));
        return fn ? static_cast<IOrgasmEngineV1*>(fn(InterfaceVersion::V1)) : nullptr;
    }

    /// V2 consumer helper. nullptr when the loaded SkyrimNet_SexLab is older (V1 only) or missing.
    [[nodiscard]] inline IOrgasmEngineV2* RequestOrgasmEngineV2()
    {
        const auto module = GetModuleHandleW(PluginDll);
        if (!module) {
            return nullptr;
        }
        const auto fn = reinterpret_cast<RequestOrgasmEngineAPIFunc>(GetProcAddress(module, RequestFunctionName));
        return fn ? static_cast<IOrgasmEngineV2*>(fn(InterfaceVersion::V2)) : nullptr;
    }
}
