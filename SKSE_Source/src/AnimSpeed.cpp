#include "AnimSpeed.h"
#include "WebUI_Log.h"

#include <algorithm>
#include <atomic>
#include <mutex>
#include <shared_mutex>
#include <unordered_map>

namespace AnimSpeed
{
    namespace
    {
        std::unordered_map<RE::FormID, float> g_speeds;
        std::unordered_map<RE::FormID, float> g_scales;
        std::shared_mutex g_lock;
        // Fast path for the per-frame hook: skip the lock while no scene has a speed set.
        std::atomic<bool> g_any{ false };

        // Caller holds g_lock (unique).
        void UpdateAny()
        {
            g_any.store(!g_speeds.empty() || !g_scales.empty(), std::memory_order_relaxed);
        }

        float Lookup(RE::Actor* a_actor)
        {
            if (!g_any.load(std::memory_order_relaxed) || !a_actor) {
                return 1.0f;
            }
            std::shared_lock lock(g_lock);
            const auto id = a_actor->GetFormID();
            const auto it = g_speeds.find(id);
            const auto sc = g_scales.find(id);
            if (it == g_speeds.end() && sc == g_scales.end()) {
                return 1.0f;
            }
            const float base = it != g_speeds.end() ? it->second : 1.0f;
            const float scale = sc != g_scales.end() ? sc->second : 1.0f;
            return std::clamp(base * scale, kMin, kMax);
        }

        struct UpdateAnimationCharacter
        {
            static void thunk(RE::Character* a_this, float a_delta)
            {
                func(a_this, a_delta * Lookup(a_this));
            }
            static inline REL::Relocation<decltype(thunk)> func;
        };

        struct UpdateAnimationPlayer
        {
            static void thunk(RE::PlayerCharacter* a_this, float a_delta)
            {
                func(a_this, a_delta * Lookup(a_this));
            }
            static inline REL::Relocation<decltype(thunk)> func;
        };

        constexpr std::size_t kUpdateAnimationIdx = 0x7D;
    }

    void Install()
    {
        REL::Relocation<std::uintptr_t> character{ RE::VTABLE_Character[0] };
        UpdateAnimationCharacter::func = character.write_vfunc(kUpdateAnimationIdx, UpdateAnimationCharacter::thunk);

        REL::Relocation<std::uintptr_t> player{ RE::VTABLE_PlayerCharacter[0] };
        UpdateAnimationPlayer::func = player.write_vfunc(kUpdateAnimationIdx, UpdateAnimationPlayer::thunk);

        webui_log::info("AnimSpeed: UpdateAnimation hooks installed");
    }

    void Set(RE::Actor* a_actor, float a_speed)
    {
        if (!a_actor) {
            return;
        }
        const float speed = std::clamp(a_speed, kMin, kMax);
        std::unique_lock lock(g_lock);
        if (speed == 1.0f) {
            g_speeds.erase(a_actor->GetFormID());
        } else {
            g_speeds[a_actor->GetFormID()] = speed;
        }
        UpdateAny();
    }

    void Clear(RE::Actor* a_actor)
    {
        if (!a_actor) {
            return;
        }
        std::unique_lock lock(g_lock);
        g_speeds.erase(a_actor->GetFormID());
        g_scales.erase(a_actor->GetFormID());
        UpdateAny();
    }

    void ClearAll()
    {
        std::unique_lock lock(g_lock);
        g_speeds.clear();
        g_scales.clear();
        g_any.store(false, std::memory_order_relaxed);
    }

    float Get(RE::Actor* a_actor)
    {
        return Lookup(a_actor);
    }

    void SetScale(RE::Actor* a_actor, float a_scale)
    {
        if (!a_actor) {
            return;
        }
        std::unique_lock lock(g_lock);
        if (a_scale == 1.0f) {
            g_scales.erase(a_actor->GetFormID());
        } else {
            g_scales[a_actor->GetFormID()] = a_scale;
        }
        UpdateAny();
    }
}
