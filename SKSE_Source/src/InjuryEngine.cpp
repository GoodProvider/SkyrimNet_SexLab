#include "InjuryEngine.h"

#include "Config.h"
#include "WebUI_Log.h"

#include <algorithm>
#include <array>
#include <functional>
#include <string_view>
#include <utility>

namespace InjuryEngine
{
    namespace
    {
        constexpr const char* kPlugin = "Injury_Engine.esp";
        constexpr const char* kScript = "Injury_Engine_Main";

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
                webui_log::warn("InjuryEngine: {}.{} dispatch failed", kScript, fn);
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
                webui_log::warn("InjuryEngine: {} is loaded but has no External_Damage (update Injury Engine)", kPlugin);
            }
            cached = api ? 1 : 0;
            webui_log::info("InjuryEngine: installed={}", api);
        }
        return cached == 1;
    }

    bool SexualParts()
    {
        return SexLabNet::GetForeignConfigBool("Injury_Engine", "injury_engine.body.include_sexual_parts", false);
    }

    int MaxStrikes()
    {
        return std::clamp(SexLabNet::GetForeignConfigInt("Injury_Engine", "injury_engine.action.max_strikes", 10), 1, 20);
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
            if (method == "slap") {
                return &kRoutes[0];
            }
            if (method == "pinch") {
                return &kRoutes[1];
            }
            if (method == "punch") {
                return &kRoutes[2];
            }
            if (method == "pull") {
                return &kRoutes[3];
            }
            return nullptr;
        }

        // Injury Engine torture type for the spell's first fire / frost / shock effect (Injury Engine's Classifier mapping),
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

    bool Strike(RE::Actor* attacker, RE::Actor* victim, const std::string& line, const std::string& part,
        std::int32_t count)
    {
        if (!victim || !Installed()) {
            return false;
        }
        webui_log::info("InjuryEngine: strike {:#x} x{} part '{}' -> '{}'", victim->GetFormID(), count, part,
            PartName(part));
        // External_Damage(attacker, victim, cause, body_part, damage_type, damage_amount, narrate)
        Call("External_Damage", std::move(attacker), std::move(victim), RE::BSFixedString(line.c_str()),
            RE::BSFixedString(PartName(part).c_str()), RE::BSFixedString("whipping"),
            static_cast<std::int32_t>(std::max(count, 1)), true);
        return true;
    }

    bool Torture(RE::Actor* attacker, RE::Actor* victim, const std::string& line, const char* type,
        const std::string& part, std::int32_t count = 1)
    {
        if (!victim || !Installed() || !type || !type[0]) {
            return false;
        }
        webui_log::info("InjuryEngine: torture {} {:#x} x{} part '{}' -> '{}'", type, victim->GetFormID(), count, part,
            PartName(part));
        Call("External_Damage", std::move(attacker), std::move(victim), RE::BSFixedString(line.c_str()),
            RE::BSFixedString(PartName(part).c_str()), RE::BSFixedString(type),
            static_cast<std::int32_t>(std::max(count, 1)), true);
        return true;
    }

    bool PunishHit(RE::Actor* attacker, RE::Actor* victim, const std::string& line, const std::string& method,
        const std::string& location, RE::FormID spell, std::int32_t count)
    {
        if (!victim || !Installed()) {
            return false;
        }
        const std::string pulldown = location == "body" ? "" : location;
        if (spell) {
            // A spell burns, freezes or shocks; it never whips. No element: the spell's own damage stands.
            const char* type = SpellTortureType(spell);
            return type && Torture(attacker, victim, line, type, pulldown, count);
        }
        if (const TortureRoute* route = TortureRouteFor(method)) {
            const std::string part = pulldown.empty() ? route->defaultPart : pulldown;
            return Torture(attacker, victim, line, route->type, part, count);
        }
        return Strike(attacker, victim, line, pulldown, count);
    }

    namespace
    {
        // Receives External_TortureText's String on a Papyrus VM thread.
        class TextCallback : public RE::BSScript::IStackCallbackFunctor
        {
        public:
            explicit TextCallback(std::function<void(std::string)> done) : done_(std::move(done)) {}
            void operator()(RE::BSScript::Variable a_result) override
            {
                std::string text;
                if (a_result.IsString()) {
                    text = std::string(a_result.GetString());
                }
                if (done_) {
                    done_(std::move(text));
                }
            }
            void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) override {}

        private:
            std::function<void(std::string)> done_;
        };

        bool TextApi()
        {
            static int cached = -1;
            if (cached < 0) {
                cached = Installed() && HasGlobal(kScript, "External_TortureText") ? 1 : 0;
                if (!cached && Installed()) {
                    webui_log::warn("InjuryEngine: no External_TortureText (update Injury Engine); punish feeling text off");
                }
            }
            return cached == 1;
        }
    }

    bool PunishText(RE::Actor* attacker, RE::Actor* victim, const std::string& method, const std::string& location,
        RE::FormID spell, std::function<void(std::string)> done, std::int32_t count)
    {
        if (!victim || !TextApi()) {
            return false;
        }
        const std::string pulldown = location == "body" ? "" : location;
        std::string type = "whipping";  // free text whips
        std::string part = pulldown;
        if (spell) {
            const char* t = SpellTortureType(spell);
            if (!t) {
                return false;
            }
            type = t;
        } else if (const TortureRoute* route = TortureRouteFor(method)) {
            type = route->type;
            part = pulldown.empty() ? route->defaultPart : pulldown;
        }
        auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
        if (!vm) {
            return false;
        }
        webui_log::info("InjuryEngine: torture text {} {:#x} x{} part '{}' -> '{}'", type, victim->GetFormID(), count,
            part, PartName(part));
        RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback{ new TextCallback(std::move(done)) };
        // External_TortureText(attacker, victim, damage_type, body_part, damage_amount)
        auto* args = RE::MakeFunctionArguments(std::move(attacker), std::move(victim),
            RE::BSFixedString(type.c_str()), RE::BSFixedString(PartName(part).c_str()),
            static_cast<std::int32_t>(std::max(count, 1)));
        if (!vm->DispatchStaticCall(kScript, "External_TortureText", args, callback)) {
            webui_log::warn("InjuryEngine: {}.External_TortureText dispatch failed", kScript);
            return false;
        }
        return true;
    }

    bool Heal(RE::Actor* caster, RE::Actor* target, const std::string& line, float health, const std::string& part,
        bool narrate)
    {
        if (!target || health <= 0.0f || !Installed()) {
            return false;
        }
        webui_log::info("InjuryEngine: heal {:#x} {:.0f} part '{}' -> '{}'", target->GetFormID(), health, part, PartName(part));
        Call("External_Heal", std::move(caster), std::move(target), RE::BSFixedString(line.c_str()), health,
            RE::BSFixedString(PartName(part).c_str()), narrate);
        return true;
    }

    void EnableSexualParts()
    {
        if (!Installed()) {
            return;
        }
        webui_log::info("InjuryEngine: enabling sexual parts");
        Call("External_SetSexualParts", true);
    }
}
