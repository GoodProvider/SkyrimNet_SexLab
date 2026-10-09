#include "Whipped.h"

#include "Config.h"
#include "WebUI_Log.h"

#include <array>
#include <string_view>
#include <utility>

namespace Whipped
{
    namespace
    {
        constexpr const char* kPlugin = "SkyrimNet_Whipped.esp";
        constexpr const char* kScript = "SkyrimNet_Whipped_Main";

        bool HasGlobal(const char* script, std::string_view fn)
        {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            RE::BSTSmartPointer<RE::BSScript::ObjectTypeInfo> type;
            if (!vm || !vm->GetScriptObjectType(RE::BSFixedString(script), type) || !type) {
                return false;
            }
            const auto* funcs = type->GetGlobalFuncIter();
            for (std::uint32_t i = 0; funcs && i < type->GetNumGlobalFuncs(); ++i) {
                if (funcs[i].func && std::string_view(funcs[i].func->GetName().c_str()) == fn) {
                    return true;
                }
            }
            return false;
        }

        template <class... Args>
        void Call(const char* fn, Args... args)
        {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                return;
            }
            auto* fargs = RE::MakeFunctionArguments(std::move(args)...);
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            if (!vm->DispatchStaticCall(kScript, fn, fargs, callback)) {
                webui_log::warn("Whipped: {}.{} dispatch failed", kScript, fn);
            }
        }
    }

    bool Installed()
    {
        // The plugin can't change during a session; the script check stays cheap after the first load.
        static int cached = -1;
        if (cached < 0) {
            auto* dh = RE::TESDataHandler::GetSingleton();
            if (!dh) {
                return false;
            }
            const bool plugin = dh->LookupModByName(kPlugin) != nullptr;
            const bool api = plugin && HasGlobal(kScript, "External_Damage");
            if (plugin && !api) {
                webui_log::warn("Whipped: {} is loaded but has no External_Damage (update SkyrimNet_Whipped)", kPlugin);
            }
            cached = api ? 1 : 0;
            webui_log::info("Whipped: installed={}", api);
        }
        return cached == 1;
    }

    bool SexualParts()
    {
        return SexLabNet::GetForeignConfigBool("SkyrimNet_Whipped", "whip.body.include_sexual_parts", false);
    }

    std::string PartName(const std::string& part)
    {
        static constexpr std::array<std::pair<std::string_view, std::string_view>, 11> kParts{ {
            { "face", "face" }, { "lips", "lips" }, { "nipples", "nipples" }, { "back", "back" },
            { "left arm", "left arm" }, { "right arm", "right arm" }, { "left leg", "left leg" },
            { "right leg", "right leg" }, { "pussy", "pussy" }, { "cock", "penis" }, { "ass", "ass hole" },
        } };
        for (const auto& [term, name] : kParts) {
            if (part == term) {
                return std::string(name);
            }
        }
        return "";
    }

    namespace
    {
        struct TortureRoute
        {
            const char* type;
            const char* defaultPart;  // pulldown term when location names no part
        };

        const TortureRoute* TortureRouteFor(std::string_view method)
        {
            static constexpr TortureRoute kRoutes[] = {
                { "slapping", "face" },
                { "pinching", "nipples" },
                { "punching", "face" },
                { "pulling", "face" },
            };
            if (method == "slap" || method == "slap face") {
                return &kRoutes[0];
            }
            if (method == "pinch" || method == "pinch nipple") {
                return &kRoutes[1];
            }
            if (method == "punch") {
                return &kRoutes[2];
            }
            if (method == "pull" || method == "pull hair") {
                return &kRoutes[3];
            }
            return nullptr;
        }

        // Whipped torture type for the spell's first fire / frost / shock effect (Whipped's Classifier mapping),
        // nullptr for none.
        const char* SpellTortureType(RE::FormID spell)
        {
            const auto* item = spell ? RE::TESForm::LookupByID<RE::MagicItem>(spell) : nullptr;
            if (!item) {
                return nullptr;
            }
            for (const auto* effect : item->effects) {
                if (!effect || !effect->baseEffect) {
                    continue;
                }
                switch (effect->baseEffect->data.resistVariable) {
                case RE::ActorValue::kResistFire:
                    return "fire";
                case RE::ActorValue::kResistFrost:
                    return "frost";
                case RE::ActorValue::kResistShock:
                    return "shock";
                default:
                    break;
                }
            }
            return nullptr;
        }
    }

    bool Strike(RE::Actor* attacker, RE::Actor* victim, const std::string& line, const std::string& part)
    {
        if (!victim || !Installed()) {
            return false;
        }
        webui_log::info("Whipped: strike {:#x} part '{}' -> '{}'", victim->GetFormID(), part, PartName(part));
        // External_Damage(attacker, victim, cause, body_part, damage_type, damage_amount, narrate)
        Call("External_Damage", std::move(attacker), std::move(victim), RE::BSFixedString(line.c_str()),
            RE::BSFixedString(PartName(part).c_str()), RE::BSFixedString("whipping"), static_cast<std::int32_t>(1), true);
        return true;
    }

    bool Torture(RE::Actor* attacker, RE::Actor* victim, const std::string& line, const char* type,
        const std::string& part)
    {
        if (!victim || !Installed() || !type || !type[0]) {
            return false;
        }
        webui_log::info("Whipped: torture {} {:#x} part '{}' -> '{}'", type, victim->GetFormID(), part, PartName(part));
        Call("External_Damage", std::move(attacker), std::move(victim), RE::BSFixedString(line.c_str()),
            RE::BSFixedString(PartName(part).c_str()), RE::BSFixedString(type), static_cast<std::int32_t>(1), true);
        return true;
    }

    bool ForceHit(RE::Actor* attacker, RE::Actor* victim, const std::string& line, const std::string& method,
        const std::string& location, RE::FormID spell)
    {
        if (!victim || !Installed()) {
            return false;
        }
        const std::string pulldown = location == "body" ? "" : location;
        if (spell) {
            // A spell burns, freezes or shocks; it never whips. No element: the spell's own damage stands.
            const char* type = SpellTortureType(spell);
            return type && Torture(attacker, victim, line, type, pulldown);
        }
        if (const TortureRoute* route = TortureRouteFor(method)) {
            const std::string part = pulldown.empty() ? route->defaultPart : pulldown;
            return Torture(attacker, victim, line, route->type, part);
        }
        return Strike(attacker, victim, line, pulldown);
    }

    bool Heal(RE::Actor* caster, RE::Actor* target, const std::string& line, float health, const std::string& part)
    {
        if (!target || health <= 0.0f || !Installed()) {
            return false;
        }
        webui_log::info("Whipped: heal {:#x} {:.0f} part '{}' -> '{}'", target->GetFormID(), health, part, PartName(part));
        Call("External_Heal", std::move(caster), std::move(target), RE::BSFixedString(line.c_str()), health,
            RE::BSFixedString(PartName(part).c_str()), true);
        return true;
    }

    void EnableSexualParts()
    {
        if (!Installed()) {
            return;
        }
        webui_log::info("Whipped: enabling sexual parts");
        Call("External_SetSexualParts", true);
    }
}
