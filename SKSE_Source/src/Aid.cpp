#include "Aid.h"

#include "WebUI_Log.h"
#include "Whipped.h"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <mutex>
#include <thread>
#include <unordered_map>
#include <unordered_set>

namespace Aid
{
    namespace
    {
        // Seconds of casting a concentration spell (Healing, Healing Hands) stands for: restore and cost per second x this.
        constexpr float kConcentrationSeconds = 3.0f;
        // Novice (0) and Apprentice (25) spells count as weak.
        constexpr std::int32_t kWeakMaxSkill = 25;
        // Seconds a fire-and-forget spell's or potion's art and shader stay on.
        constexpr float kVisualSeconds = 2.0f;

        std::string NameOf(const RE::TESForm* form)
        {
            const char* name = form ? form->GetName() : nullptr;
            return name ? name : "";
        }

        std::string ActorName(RE::Actor* actor)
        {
            const char* name = actor ? actor->GetDisplayFullName() : nullptr;
            return name ? name : "";
        }

        std::string Lower(std::string_view s)
        {
            std::string out;
            out.reserve(s.size());
            for (const unsigned char c : s) {
                out.push_back(static_cast<char>(std::tolower(c)));
            }
            return out;
        }

        float CurrentAv(RE::Actor* actor, RE::ActorValue av)
        {
            auto* owner = actor ? actor->AsActorValueOwner() : nullptr;
            return owner ? owner->GetActorValue(av) : 0.0f;
        }

        bool IsConcentration(const RE::MagicItem* item)
        {
            return item->GetCastingType() == RE::MagicSystem::CastingType::kConcentration;
        }

        // Health / stamina restored by the item's beneficial Value Modifier effects (magnitude x duration;
        // a concentration spell as kConcentrationSeconds of casting).
        void RestoresOf(const RE::MagicItem* item, float& health, float& stamina)
        {
            health = 0.0f;
            stamina = 0.0f;
            const float seconds = IsConcentration(item) ? kConcentrationSeconds : 1.0f;
            for (const auto* e : item->effects) {
                const auto* mgef = e ? e->baseEffect : nullptr;
                if (!mgef || mgef->IsDetrimental() || mgef->IsHostile() ||
                    mgef->GetArchetype() != RE::EffectArchetypes::ArchetypeID::kValueModifier) {
                    continue;
                }
                const float amount = e->effectItem.magnitude *
                                     std::max(seconds, static_cast<float>(e->effectItem.duration));
                if (mgef->data.primaryAV == RE::ActorValue::kHealth) {
                    health += amount;
                } else if (mgef->data.primaryAV == RE::ActorValue::kStamina) {
                    stamina += amount;
                }
            }
        }

        // Castable spells: base spell list plus spells added in game (learned), once each.
        std::vector<RE::SpellItem*> KnownSpells(RE::Actor* actor)
        {
            std::vector<RE::SpellItem*> out;
            std::unordered_set<RE::SpellItem*> seen;
            const auto add = [&](RE::SpellItem* s) {
                if (s && s->GetSpellType() == RE::MagicSystem::SpellType::kSpell &&
                    s->GetCastingType() != RE::MagicSystem::CastingType::kConstantEffect && seen.insert(s).second) {
                    out.push_back(s);
                }
            };
            if (auto* npc = actor->GetActorBase()) {
                if (const auto* list = npc->GetSpellList(); list && list->spells) {
                    for (std::uint32_t i = 0; i < list->numSpells; ++i) {
                        add(list->spells[i]);
                    }
                }
            }
            for (auto* s : actor->GetActorRuntimeData().addedSpells) {
                add(s);
            }
            return out;
        }

        float SpellCost(RE::SpellItem* spell, RE::Actor* caster)
        {
            const float cost = spell->CalculateMagickaCost(caster);
            return IsConcentration(spell) ? cost * kConcentrationSeconds : cost;
        }

        void Restore(RE::Actor* target, float health, float stamina)
        {
            auto* owner = target ? target->AsActorValueOwner() : nullptr;
            if (!owner) {
                return;
            }
            if (health > 0.0f) {
                owner->RestoreActorValue(RE::ActorValue::kHealth, health);
            }
            if (stamina > 0.0f) {
                owner->RestoreActorValue(RE::ActorValue::kStamina, stamina);
            }
        }

        void PlayEffectSound(RE::Actor* actor, RE::BGSSoundDescriptorForm* sound)
        {
            auto* audio = RE::BSAudioManager::GetSingleton();
            auto* node = actor ? actor->Get3D() : nullptr;
            if (!audio || !sound || !node) {
                return;
            }
            RE::BSSoundHandle handle;
            if (audio->GetSoundHandle(handle, sound) && handle.IsValid()) {
                handle.SetPosition(actor->GetPosition());
                handle.SetObjectToFollow(node);
                handle.Play();
            }
        }

        // Visual cast (main thread): the item's casting art on the caster's hands (spells), its effect shader and hit
        // art on the target, and its release / hit sounds. Amounts are applied separately; nothing is cast, so no
        // combat, no bounty, and a self-delivery spell (Healing) still shows on another actor.
        // seconds < 0: the item's default (kConcentrationSeconds / kVisualSeconds).
        void PlaySpellVisuals(RE::Actor* caster, RE::Actor* target, const RE::MagicItem* item, bool potion,
            float seconds = -1.0f)
        {
            if (!target || !item) {
                return;
            }
            const float dur = seconds >= 0.0f ? seconds : IsConcentration(item) ? kConcentrationSeconds : kVisualSeconds;
            std::unordered_set<const RE::EffectSetting*> seen;
            std::int32_t art = 0;
            std::int32_t shaders = 0;
            std::int32_t sounds = 0;
            for (const auto* e : item->effects) {
                auto* mgef = e ? e->baseEffect : nullptr;
                if (!mgef || !seen.insert(mgef).second) {
                    continue;
                }
                if (!potion && caster && mgef->data.castingArt && caster->ApplyArtObject(mgef->data.castingArt, dur)) {
                    ++art;
                }
                if (mgef->data.effectShader && target->ApplyEffectShader(mgef->data.effectShader, dur)) {
                    ++shaders;
                }
                if (mgef->data.hitEffectArt && target->ApplyArtObject(mgef->data.hitEffectArt, dur)) {
                    ++art;
                }
                for (const auto& pair : mgef->effectSounds) {
                    if (!potion && pair.id == RE::MagicSystem::SoundID::kRelease) {
                        PlayEffectSound(caster, pair.sound);
                        ++sounds;
                    } else if (pair.id == RE::MagicSystem::SoundID::kHit) {
                        PlayEffectSound(target, pair.sound);
                        ++sounds;
                    }
                }
            }
            webui_log::info("Aid: visuals '{}' {:#x} -> {:#x} art {} shaders {} sounds {} ({:.1f}s)", NameOf(item),
                caster ? caster->GetFormID() : 0, target->GetFormID(), art, shaders, sounds, dur);
        }

        // Narration line; part "" means no body part.
        std::string AidLine(RE::Actor* caster, RE::Actor* target, const Option& o, const std::string& part)
        {
            const std::string who = ActorName(caster);
            const std::string whom = ActorName(target);
            const bool self = caster == target;
            if (!part.empty()) {
                const auto* base = target->GetActorBase();
                const std::string own = (base && base->GetSex() == RE::SEX::kFemale) ? "her own " : "his own ";
                const std::string where = (self ? own : whom + "'s ") + part;
                return who + (o.potion ? " pours a " : " casts ") + o.name + " on " + where + ".";
            }
            if (o.potion) {
                return self ? who + " drinks a " + o.name + "." : who + " gives " + whom + " a " + o.name + ".";
            }
            return self ? who + " casts " + o.name + "." : who + " casts " + o.name + " on " + whom + ".";
        }

        // ── Channels (Aid panel points): a spell kept up until a number of points is restored ──

        constexpr auto kChannelPoll = std::chrono::milliseconds(250);
        constexpr float kChannelPollSeconds = 0.25f;

        struct Channel
        {
            RE::FormID target = 0;
            RE::FormID spell = 0;
            std::string line;
            std::string part;
            bool toWhipped = false;
            bool stamina = false;     // counts stamina (a stamina-only spell), else health
            float points = 0.0f;      // to restore
            float done = 0.0f;        // restored so far
            float interval = 1.0f;    // seconds between ticks (casts)
            float health = 0.0f;      // per tick
            float staminaAmt = 0.0f;  // per tick
            float wait = 0.0f;        // seconds until the next tick
            bool first = true;
            std::uint64_t gen = 0;    // tells a channel from the one that replaced it
        };

        std::mutex g_channelLock;
        std::unordered_map<RE::FormID, Channel> g_channels;  // by caster
        bool g_channelThread = false;                       // under g_channelLock
        std::uint64_t g_channelGen = 0;                     // under g_channelLock

        // Health / stamina restored per tick (a concentration spell's magnitude per second over interval seconds, a
        // fire-and-forget spell's full cast) and the magicka a tick costs.
        void TickAmounts(RE::SpellItem* spell, RE::Actor* caster, float interval, float& health, float& stamina,
            float& cost)
        {
            if (!IsConcentration(spell)) {
                RestoresOf(spell, health, stamina);
                cost = spell->CalculateMagickaCost(caster);
                return;
            }
            health = 0.0f;
            stamina = 0.0f;
            for (const auto* e : spell->effects) {
                const auto* mgef = e ? e->baseEffect : nullptr;
                if (!mgef || mgef->IsDetrimental() || mgef->IsHostile() ||
                    mgef->GetArchetype() != RE::EffectArchetypes::ArchetypeID::kValueModifier) {
                    continue;
                }
                if (mgef->data.primaryAV == RE::ActorValue::kHealth) {
                    health += e->effectItem.magnitude * interval;
                } else if (mgef->data.primaryAV == RE::ActorValue::kStamina) {
                    stamina += e->effectItem.magnitude * interval;
                }
            }
            cost = spell->CalculateMagickaCost(caster) * interval;
        }

        // Game thread. One tick of the channel; false when it is over (reason logged).
        bool AdvanceChannel(RE::FormID casterId, Channel& ch)
        {
            const auto stop = [&](const char* why) {
                webui_log::info("Aid: channel {:#x} -> {:#x} stopped ({}) restored {:.0f}/{:.0f}", casterId, ch.target,
                    why, ch.done, ch.points);
                return false;
            };
            auto* c = RE::TESForm::LookupByID<RE::Actor>(casterId);
            auto* t = RE::TESForm::LookupByID<RE::Actor>(ch.target);
            auto* spell = RE::TESForm::LookupByID<RE::SpellItem>(ch.spell);
            if (!c || !t || !spell || c->IsDead() || t->IsDead() || !c->Is3DLoaded() || !t->Is3DLoaded()) {
                return stop("actor gone");
            }
            auto* casterAv = c->AsActorValueOwner();
            auto* targetAv = t->AsActorValueOwner();
            if (!casterAv || !targetAv) {
                return stop("actor gone");
            }
            const auto av = ch.stamina ? RE::ActorValue::kStamina : RE::ActorValue::kHealth;
            const float missing = targetAv->GetPermanentActorValue(av) - targetAv->GetActorValue(av);
            const float owed = ch.points - ch.done;
            if (owed < 0.5f) {
                return stop("target reached");
            }
            if (missing < 0.5f) {
                return stop("full");
            }
            float health = 0.0f;
            float stamina = 0.0f;
            float cost = 0.0f;
            TickAmounts(spell, c, ch.interval, health, stamina, cost);
            if (cost > 0.0f && casterAv->GetActorValue(RE::ActorValue::kMagicka) < cost) {
                return stop("out of magicka");
            }
            // Last tick: only what is still owed (the other value scaled with it).
            const float counted = ch.stamina ? stamina : health;
            const float scale = counted > owed ? owed / counted : 1.0f;
            health *= scale;
            stamina *= scale;
            if (cost > 0.0f) {
                casterAv->DamageActorValue(RE::ActorValue::kMagicka, cost * scale);
            }
            Restore(t, ch.toWhipped ? 0.0f : health, stamina);
            if (ch.toWhipped) {
                Whipped::Heal(c, t, ch.line, health, ch.part, ch.first);
            }
            ch.first = false;
            ch.done += std::min(counted * scale, missing);
            PlaySpellVisuals(c, t, spell, false, ch.interval + kChannelPollSeconds);
            return ch.done < ch.points - 0.5f || stop("target reached");
        }

        // Game thread, every kChannelPoll.
        void ChannelTick()
        {
            auto* ui = RE::UI::GetSingleton();
            if (ui && ui->GameIsPaused()) {
                return;
            }
            std::vector<std::pair<RE::FormID, Channel>> due;
            {
                std::lock_guard lock(g_channelLock);
                for (auto& [caster, ch] : g_channels) {
                    ch.wait -= kChannelPollSeconds;
                    if (ch.wait <= 0.0f) {
                        due.emplace_back(caster, ch);
                    }
                }
            }
            for (auto& [caster, ch] : due) {
                const bool keep = AdvanceChannel(caster, ch);
                std::lock_guard lock(g_channelLock);
                const auto it = g_channels.find(caster);
                // A newer Aid from this caster replaced it meanwhile: leave the new one alone.
                if (it == g_channels.end() || it->second.gen != ch.gen) {
                    continue;
                }
                if (!keep) {
                    g_channels.erase(it);
                    continue;
                }
                ch.wait = ch.interval;
                it->second = std::move(ch);
            }
        }

        void EnsureChannelThread()
        {
            if (g_channelThread) {
                return;
            }
            g_channelThread = true;
            std::thread([]() {
                while (true) {
                    std::this_thread::sleep_for(kChannelPoll);
                    {
                        std::lock_guard lock(g_channelLock);
                        if (g_channels.empty()) {
                            g_channelThread = false;
                            return;
                        }
                    }
                    if (auto* tasks = SKSE::GetTaskInterface()) {
                        tasks->AddTask([]() { ChannelTick(); });
                    }
                }
            }).detach();
        }
    }

    std::vector<Option> ListOptions(RE::Actor* caster)
    {
        std::vector<Option> spells;
        std::vector<Option> potions;
        if (!caster) {
            return spells;
        }
        const float magicka = CurrentAv(caster, RE::ActorValue::kMagicka);
        for (auto* s : KnownSpells(caster)) {
            Option o;
            RestoresOf(s, o.health, o.stamina);
            if (o.health <= 0.0f && o.stamina <= 0.0f) {
                continue;
            }
            o.form = s->GetFormID();
            o.name = NameOf(s);
            o.cost = SpellCost(s, caster);
            o.affordable = o.cost <= magicka;
            spells.push_back(std::move(o));
        }
        const auto inv = caster->GetInventory([](RE::TESBoundObject& o) { return o.Is(RE::FormType::AlchemyItem); });
        for (const auto& [obj, data] : inv) {
            auto* potion = obj ? obj->As<RE::AlchemyItem>() : nullptr;
            if (!potion || data.first <= 0 || potion->IsFood() || potion->IsPoison()) {
                continue;
            }
            Option o;
            RestoresOf(potion, o.health, o.stamina);
            if (o.health <= 0.0f && o.stamina <= 0.0f) {
                continue;
            }
            o.form = potion->GetFormID();
            o.name = NameOf(potion);
            o.potion = true;
            o.count = data.first;
            potions.push_back(std::move(o));
        }
        const auto byName = [](const Option& a, const Option& b) { return a.name < b.name; };
        std::sort(spells.begin(), spells.end(), byName);
        std::sort(potions.begin(), potions.end(), byName);
        spells.insert(spells.end(), std::make_move_iterator(potions.begin()), std::make_move_iterator(potions.end()));
        return spells;
    }

    bool HasOptions(RE::Actor* caster)
    {
        const auto options = ListOptions(caster);
        return std::any_of(options.begin(), options.end(), [](const Option& o) { return o.affordable; });
    }

    RE::FormID PickBest(RE::Actor* caster, std::string_view kind)
    {
        const bool stamina = Lower(kind).find("stam") != std::string::npos;
        const Option* best = nullptr;
        for (const auto& o : ListOptions(caster)) {
            const float amount = stamina ? o.stamina : o.health;
            if (amount <= 0.0f || !o.affordable) {
                continue;
            }
            if (!best) {
                best = &o;
                continue;
            }
            const float bestAmount = stamina ? best->stamina : best->health;
            // A spell beats any potion; then the larger amount.
            if ((best->potion && !o.potion) || (best->potion == o.potion && amount > bestAmount)) {
                best = &o;
            }
        }
        return best ? best->form : 0;
    }

    std::string Apply(RE::Actor* caster, RE::Actor* target, RE::FormID form, const std::string& location, bool* whipped)
    {
        if (whipped) {
            *whipped = false;
        }
        if (!caster || !target || !form) {
            return "";
        }
        const auto options = ListOptions(caster);
        const auto it = std::find_if(options.begin(), options.end(), [form](const Option& o) { return o.form == form; });
        if (it == options.end() || !it->affordable) {
            webui_log::warn("Aid: {:#x} cannot use {:#x} (not known / carried / affordable)", caster->GetFormID(), form);
            return "";
        }
        const Option o = *it;
        const RE::FormID casterId = caster->GetFormID();
        const RE::FormID targetId = target->GetFormID();

        // HUD body part ("body" / "": none): "on Lydia's ass" / "on her own ass".
        const std::string part = location == "body" ? "" : location;
        const std::string line = AidLine(caster, target, o, part);

        // SkyrimNet_Whipped heals the wounds on the part (and the health with them) and narrates the line.
        const bool toWhipped = o.health > 0.0f && Whipped::Installed();
        if (whipped) {
            *whipped = toWhipped;
        }
        SKSE::GetTaskInterface()->AddTask([o, casterId, targetId, toWhipped, line, part]() {
            auto* c = RE::TESForm::LookupByID<RE::Actor>(casterId);
            auto* t = RE::TESForm::LookupByID<RE::Actor>(targetId);
            if (!c || !t) {
                return;
            }
            if (o.potion) {
                auto* potion = RE::TESForm::LookupByID<RE::AlchemyItem>(o.form);
                if (!potion) {
                    return;
                }
                c->RemoveItem(potion, 1, RE::ITEM_REMOVE_REASON::kRemove, nullptr, nullptr);
            } else if (auto* owner = c->AsActorValueOwner(); owner && o.cost > 0.0f) {
                owner->DamageActorValue(RE::ActorValue::kMagicka, o.cost);
            }
            Restore(t, toWhipped ? 0.0f : o.health, o.stamina);
            if (toWhipped) {
                Whipped::Heal(c, t, line, o.health, part);
            }
            PlaySpellVisuals(c, t, RE::TESForm::LookupByID<RE::MagicItem>(o.form), o.potion);
        });
        webui_log::info("Aid: {:#x} -> {:#x} {} '{}' on '{}' health {:.0f} stamina {:.0f} cost {:.0f} whipped {}", casterId,
            targetId, o.potion ? "potion" : "spell", o.name, location, o.health, o.stamina, o.cost, toWhipped);
        return line;
    }

    std::string StartChannel(RE::Actor* caster, RE::Actor* target, RE::FormID form, const std::string& location,
        float points, bool* whipped)
    {
        if (whipped) {
            *whipped = false;
        }
        if (!caster || !target || !form) {
            return "";
        }
        auto* spell = RE::TESForm::LookupByID<RE::SpellItem>(form);
        if (points <= 0.0f || !spell) {
            return Apply(caster, target, form, location, whipped);
        }
        const auto options = ListOptions(caster);
        const auto it = std::find_if(options.begin(), options.end(), [form](const Option& o) { return o.form == form; });
        if (it == options.end() || it->potion) {
            webui_log::warn("Aid: {:#x} cannot channel {:#x} (not known)", caster->GetFormID(), form);
            return "";
        }
        const Option& o = *it;
        Channel ch;
        ch.target = target->GetFormID();
        ch.spell = form;
        ch.part = location == "body" ? "" : location;
        ch.line = AidLine(caster, target, o, ch.part);
        ch.stamina = o.health <= 0.0f;
        ch.toWhipped = !ch.stamina && Whipped::Installed();
        ch.points = points;
        ch.interval = IsConcentration(spell) ? 1.0f : std::max(1.0f, spell->GetChargeTime() + 0.5f);
        if (whipped) {
            *whipped = ch.toWhipped;
        }
        const RE::FormID casterId = caster->GetFormID();
        {
            std::lock_guard lock(g_channelLock);
            ch.gen = ++g_channelGen;
            if (g_channels.contains(casterId)) {
                webui_log::info("Aid: channel {:#x} replaced", casterId);
            }
            g_channels[casterId] = ch;
            EnsureChannelThread();
        }
        webui_log::info("Aid: channel {:#x} -> {:#x} '{}' on '{}' {:.0f} {} every {:.2f}s whipped {}", casterId,
            ch.target, o.name, location, points, ch.stamina ? "stamina" : "health", ch.interval, ch.toWhipped);
        return ch.line;
    }

    std::vector<WeakSpell> WeakAttackSpells(RE::Actor* actor)
    {
        std::vector<WeakSpell> out;
        if (!actor) {
            return out;
        }
        for (auto* s : KnownSpells(actor)) {
            const auto* costliest = s->GetCostliestEffectItem();
            if (!costliest || !costliest->baseEffect || costliest->baseEffect->GetMinimumSkillLevel() > kWeakMaxSkill) {
                continue;
            }
            float minDamage = 0.0f;
            for (const auto* e : s->effects) {
                const auto* mgef = e ? e->baseEffect : nullptr;
                if (!mgef || !mgef->IsHostile() || !mgef->IsDetrimental() ||
                    mgef->GetArchetype() != RE::EffectArchetypes::ArchetypeID::kValueModifier ||
                    mgef->data.primaryAV != RE::ActorValue::kHealth || e->effectItem.magnitude <= 0.0f) {
                    continue;
                }
                const float mag = e->effectItem.magnitude;
                minDamage = minDamage <= 0.0f ? mag : std::min(minDamage, mag);
            }
            if (minDamage > 0.0f) {
                out.push_back({ s->GetFormID(), NameOf(s), minDamage });
            }
        }
        std::sort(out.begin(), out.end(), [](const WeakSpell& a, const WeakSpell& b) { return a.name < b.name; });
        return out;
    }

    const WeakSpell* FindWeakSpell(const std::vector<WeakSpell>& spells, std::string_view name)
    {
        const std::string key = Lower(name);
        for (const auto& s : spells) {
            if (!s.name.empty() && Lower(s.name) == key) {
                return &s;
            }
        }
        return nullptr;
    }

    void QueueWeakSpellHit(RE::Actor* forcer, RE::Actor* victim, RE::FormID spell, float dmg)
    {
        if (!victim || dmg < 0.0f) {
            return;
        }
        const RE::FormID id = victim->GetFormID();
        const RE::FormID forcerId = forcer ? forcer->GetFormID() : 0;
        SKSE::GetTaskInterface()->AddTask([id, forcerId, spell, dmg]() {
            auto* v = RE::TESForm::LookupByID<RE::Actor>(id);
            auto* owner = v ? v->AsActorValueOwner() : nullptr;
            if (!owner) {
                return;
            }
            const float hit = std::min(dmg, owner->GetActorValue(RE::ActorValue::kHealth) - 1.0f);
            if (hit > 0.0f) {
                owner->DamageActorValue(RE::ActorValue::kHealth, hit);
            }
            webui_log::info("Aid: weak spell hit {:#x} for {:.1f} (asked {:.1f})", id, std::max(hit, 0.0f), dmg);
            PlaySpellVisuals(forcerId ? RE::TESForm::LookupByID<RE::Actor>(forcerId) : nullptr, v,
                RE::TESForm::LookupByID<RE::MagicItem>(spell), false);
        });
    }
}
