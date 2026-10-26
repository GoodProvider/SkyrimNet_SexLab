#include "Papyrus_AnimationDB.h"
#include "JsonUtil.h"
#include "AnimationDB.h"
#include "BondageCatalog.h"
#include "Config.h"
#include "SlalLoader.h"
#include "SlsbLoader.h"
#include "WebUI_Log.h"

#include <nlohmann/json.hpp>

namespace PapyrusBindings_AnimationDB
{
    namespace
    {
        AnimationDB::FilterSpec ParseFilter(const char* json)
        {
            AnimationDB::FilterSpec spec;
            if (!json || !json[0])
                return spec;
            try {
                auto j = nlohmann::json::parse(json);
                if (j.contains("_actor_count") && j["_actor_count"].is_number())
                    spec.actor_count = j["_actor_count"].get<int>();
                else if (j.contains("actor_count") && j["actor_count"].is_number())
                    spec.actor_count = j["actor_count"].get<int>();

                auto read_tags = [&](const char* k1, const char* k2, std::vector<std::string>& out) {
                    const nlohmann::json* arr = nullptr;
                    if (j.contains(k1) && j[k1].is_array())
                        arr = &j[k1];
                    else if (j.contains(k2) && j[k2].is_array())
                        arr = &j[k2];
                    if (!arr)
                        return;
                    for (const auto& el : *arr) {
                        if (el.is_string())
                            out.push_back(AnimationDB::ToLower(el.get<std::string>()));
                    }
                };
                read_tags("_must_tags", "must_tags", spec.must_tags);
                read_tags("_suppress_tags", "suppress_tags", spec.suppress_tags);

                if (j.contains("_require_all") && j["_require_all"].is_boolean())
                    spec.require_all = j["_require_all"].get<bool>();
                else if (j.contains("require_all") && j["require_all"].is_boolean())
                    spec.require_all = j["require_all"].get<bool>();
                else if (!spec.must_tags.empty())
                    spec.require_all = true;

                if (j.contains("_creature") && j["_creature"].is_string()) {
                    auto c = AnimationDB::ToLower(j["_creature"].get<std::string>());
                    if (c == "require")
                        spec.creature = 1;
                    else if (c == "exclude")
                        spec.creature = 2;
                }
                if (j.contains("_enabled_only") && j["_enabled_only"].is_boolean())
                    spec.enabled_only = j["_enabled_only"].get<bool>();
                if (j.contains("_position_match") && j["_position_match"].is_boolean())
                    spec.position_match = j["_position_match"].get<bool>();
                if (j.contains("_pos_genders") && j["_pos_genders"].is_array()) {
                    for (const auto& el : j["_pos_genders"]) {
                        if (el.is_number_integer())
                            spec.pos_genders.push_back(el.get<int>());
                    }
                }
                if (j.contains("_pos_intersex") && j["_pos_intersex"].is_array()) {
                    for (const auto& el : j["_pos_intersex"])
                        spec.pos_intersex.push_back(el.is_number() && el.get<double>() != 0 ? 1 : 0);
                }
                if (j.contains("_pos_race_keys") && j["_pos_race_keys"].is_array()) {
                    for (const auto& el : j["_pos_race_keys"]) {
                        if (el.is_string())
                            spec.pos_race_keys.push_back(AnimationDB::ToLower(el.get<std::string>()));
                    }
                }
                if (j.contains("_has_description") || j.contains("has_description"))
                    spec.has_description = AnimationDB::ParseHasDescriptionMode(j);
                if (j.contains("_gender_match") && j["_gender_match"].is_boolean())
                    spec.gender_match = j["_gender_match"].get<bool>();
                if (j.contains("_males") && j["_males"].is_number_integer())
                    spec.males = j["_males"].get<int>();
                if (j.contains("_females") && j["_females"].is_number_integer())
                    spec.females = j["_females"].get<int>();
                if (j.contains("_intersex") && j["_intersex"].is_number_integer())
                    spec.intersex = j["_intersex"].get<int>();
                if (j.contains("_male_creatures") && j["_male_creatures"].is_number_integer())
                    spec.male_creatures = j["_male_creatures"].get<int>();
                if (j.contains("_female_creatures") && j["_female_creatures"].is_number_integer())
                    spec.female_creatures = j["_female_creatures"].get<int>();
                if (j.contains("_synonyms") && j["_synonyms"].is_string())
                    spec.synonyms = AnimationDB::ParseSynonymMode(j["_synonyms"].get<std::string>());
                // JContainers writes bools as ints.
                if (j.contains("_shuffle"))
                    spec.shuffle = j["_shuffle"].is_boolean() ? j["_shuffle"].get<bool>()
                                   : j["_shuffle"].is_number() && j["_shuffle"].get<double>() != 0;
                // Scene-setting keys. Papyrus natives run on the main thread, so `_form_ids` (the cast)
                // can be scanned for worn DD here to decide tags_suppress_unless_bound.
                std::optional<bool> bound;
                if (!j.contains("_bound") && j.contains("_form_ids") && j["_form_ids"].is_array()) {
                    std::vector<RE::Actor*> cast;
                    for (const auto& el : j["_form_ids"]) {
                        if (!el.is_number())
                            continue;
                        const auto formId = el.is_number_integer()
                                                ? static_cast<std::uint32_t>(el.get<std::int64_t>())
                                                : static_cast<std::uint32_t>(el.get<double>());
                        if (auto* actor = formId ? RE::TESForm::LookupByID<RE::Actor>(formId) : nullptr)
                            cast.push_back(actor);
                    }
                    bound = !BondageCatalog::WornAnimationTags(cast).empty();
                }
                AnimationDB::ParseSceneFilterKeys(j, spec, bound);
            } catch (...) {
                webui_log::warn("AnimationDB: bad filter JSON");
            }
            return spec;
        }

        nlohmann::json RowToJson(const AnimationDB::AnimRow& row)
        {
            nlohmann::json j;
            j["_registry"] = row.registry;
            j["_name"] = row.name;
            j["_enabled"] = row.enabled;
            j["_source"] = row.source;
            j["_position_count"] = row.position_count;
            j["_stage_count"] = row.stage_count;
            j["_has_creature"] = row.has_creature;
            j["_race_type"] = row.race_type;
            j["_pos_genders"] = row.pos_genders;
            j["_pos_race_keys"] = row.pos_race_keys;
            j["_tags"] = row.tags;
            j["_pos_no_orgasm"] = row.pos_no_orgasm;
            j["_pos_speaking_modifiers"] = row.pos_speaking_modifiers;
            j["_clothed"] = row.pos_clothed;
            j["_stage_has_description"] = row.stage_has_description;
            nlohmann::json sd = nlohmann::json::object();
            for (const auto& [k, v] : row.stage_descriptions)
                sd[std::to_string(k)] = v;
            j["_stage_descriptions"] = sd;
            nlohmann::json ss = nlohmann::json::object();
            for (const auto& [k, v] : row.stage_speaking)
                ss[std::to_string(k)] = v;
            j["_stage_speaking"] = ss;
            nlohmann::json sc = nlohmann::json::object();
            for (const auto& [k, v] : row.stage_clothed)
                sc[std::to_string(k)] = v;
            j["_stage_clothed"] = sc;
            nlohmann::json st = nlohmann::json::object();
            for (const auto& [k, v] : row.stage_tags)
                st[std::to_string(k)] = v;
            j["_stage_tags"] = st;
            j["_transitions"] = row.transitions.is_object() ? row.transitions : nlohmann::json::object();
            j["_file_tags"] = row.file_tags;
            if (!row.creator.empty())
                j["_creator"] = row.creator;
            return j;
        }

        // Papyrus-built ["name",...]. A non-pyro compiler stores "\"" as backslash+quote
        // (KNOWLEDGEBASE "{{sl.actors.N}} reached SkyrimNet raw"), so retry once unescaped.
        std::vector<std::string> ParseActorNames(const char* actors_json, const char* caller)
        {
            std::vector<std::string> names;
            std::string text = actors_json ? actors_json : "[]";
            nlohmann::json j;
            try {
                j = nlohmann::json::parse(text);
            } catch (const std::exception& e) {
                std::string fixed = text;
                for (size_t pos = 0; (pos = fixed.find("\\\"", pos)) != std::string::npos; ++pos)
                    fixed.erase(pos, 1);
                try {
                    j = nlohmann::json::parse(fixed);
                    webui_log::warn("{}: actors_json had literal \\\" (pex not built with pyro); unescaped | json='{}'",
                        caller, text);
                } catch (...) {
                    webui_log::warn("{}: actors_json parse failed: {} | json='{}'", caller, e.what(), text);
                    return names;
                }
            }
            if (j.is_array()) {
                for (const auto& el : j) {
                    if (el.is_string())
                        names.push_back(el.get<std::string>());
                }
            }
            return names;
        }
    }

    void AnimDb_Open(RE::StaticFunctionTag*)
    {
        AnimationDB::Open();
    }

    std::int32_t AnimDb_BeginSync(RE::StaticFunctionTag*, bool force_rebuild)
    {
        return static_cast<std::int32_t>(AnimationDB::BeginSync(force_rebuild));
    }

    // Papyrus-built batch from SkyrimNet_SexLab_AnimDb (WalkPPlusBatch / OnUpdate). A pex built by papyrus.exe keeps
    // "\"" as backslash+quote (KNOWLEDGEBASE "non-pyro compiler kept \" literally"), so every batch fails to parse:
    // log where, then retry once unescaped so a bad build still fills the DB.
    std::int32_t AnimDb_PushAnimBatch(RE::StaticFunctionTag*, RE::BSFixedString json)
    {
        const std::string text = json.c_str() ? json.c_str() : "";
        try {
            auto j = nlohmann::json::parse(text);
            return AnimationDB::PushAnimBatch(j);
        } catch (const nlohmann::json::parse_error& e) {
            const int failures = AnimationDB::NoteBatchParseError();
            if (failures == 1) {
                const size_t at = e.byte > 0 ? static_cast<size_t>(e.byte - 1) : 0;
                const size_t from = at > 60 ? at - 60 : 0;
                webui_log::warn("AnimDb_PushAnimBatch: parse failed len={} byte={}: {} | near='{}'", text.size(),
                    e.byte, e.what(), text.substr(from, 120));
            }
            if (text.find("\\\"") != std::string::npos) {
                std::string fixed = text;
                for (size_t pos = 0; (pos = fixed.find("\\\"", pos)) != std::string::npos; ++pos)
                    fixed.erase(pos, 1);
                try {
                    auto j = nlohmann::json::parse(fixed);
                    if (failures == 1)
                        webui_log::warn("AnimDb_PushAnimBatch: batch had literal \\\" (pex not built with pyro); "
                                        "unescaped");
                    return AnimationDB::PushAnimBatch(j);
                } catch (const std::exception& e2) {
                    if (failures <= 3)
                        webui_log::warn("AnimDb_PushAnimBatch: unescaped retry failed: {}", e2.what());
                }
            }
            AnimationDB::NoteBatchDropped();
            return 0;
        } catch (const std::exception& e) {
            AnimationDB::NoteBatchDropped();
            webui_log::warn("AnimDb_PushAnimBatch: failed len={}: {}", text.size(), e.what());
            return 0;
        }
    }

    bool AnimDb_EndSync(RE::StaticFunctionTag*)
    {
        return AnimationDB::EndSync();
    }

    // AnimDB as the registry: load SLAL packs from disk on a worker thread (SlalLoader). False: one is running
    // (this request queues behind it).
    bool AnimDb_SyncFromSlal(RE::StaticFunctionTag*, bool force_rebuild, bool drop_legacy)
    {
        return SlalLoader::StartAsync(force_rebuild, drop_legacy);
    }

    bool AnimDb_IsSlalSyncRunning(RE::StaticFunctionTag*)
    {
        return SlalLoader::IsRunning();
    }

    RE::BSFixedString AnimDb_SlalSummary(RE::StaticFunctionTag*)
    {
        return RE::BSFixedString(SlalLoader::LastSummary());
    }

    // SexLab P+: load SLSB scene packs from disk (SlsbLoader), same contract as AnimDb_SyncFromSlal.
    bool AnimDb_SyncFromSlsb(RE::StaticFunctionTag*, bool force_rebuild, bool drop_legacy)
    {
        return SlsbLoader::StartAsync(force_rebuild, drop_legacy);
    }

    bool AnimDb_IsSlsbSyncRunning(RE::StaticFunctionTag*)
    {
        return SlsbLoader::IsRunning();
    }

    RE::BSFixedString AnimDb_SlsbSummary(RE::StaticFunctionTag*)
    {
        return RE::BSFixedString(SlsbLoader::LastSummary());
    }

    // sexlab.anim_engine.slsb_registry: on P+, SlsbLoader owns AnimDB instead of the Papyrus walk (default off
    // until in-game parity with the walk).
    bool AnimDb_SlsbRegistryEnabled(RE::StaticFunctionTag*)
    {
        return SexLabNet::GetConfigBool("sexlab.anim_engine.slsb_registry", false);
    }

    RE::BSFixedString AnimDb_GetPlaybackJson(RE::StaticFunctionTag*, RE::BSFixedString registry)
    {
        return RE::BSFixedString(AnimationDB::GetPlaybackJson(registry.c_str() ? registry.c_str() : ""));
    }

    bool AnimDb_SetEnabled(RE::StaticFunctionTag*, RE::BSFixedString registry, bool enabled)
    {
        return AnimationDB::SetAnimEnabled(registry.c_str() ? registry.c_str() : "", enabled);
    }

    bool AnimDb_RecordPlay(RE::StaticFunctionTag*, RE::BSFixedString registry)
    {
        return AnimationDB::RecordPlay(registry.c_str() ? registry.c_str() : "");
    }

    RE::BSFixedString AnimDb_QueryTopNAnims(RE::StaticFunctionTag*, RE::BSFixedString filter_json,
        std::int32_t n)
    {
        auto spec = ParseFilter(filter_json.c_str());
        auto rows = AnimationDB::QueryTopNAnims(spec, n);
        nlohmann::json arr = nlohmann::json::array();
        for (const auto& row : rows)
            arr.push_back(RowToJson(row));
        return RE::BSFixedString(SafeDump(arr));
    }

    RE::BSFixedString AnimDb_QueryTopNTags(RE::StaticFunctionTag*, RE::BSFixedString filter_json,
        std::int32_t n)
    {
        auto spec = ParseFilter(filter_json.c_str());
        auto tags = AnimationDB::QueryTopNTags(spec, n);
        nlohmann::json arr = nlohmann::json::array();
        for (const auto& t : tags) {
            nlohmann::json o;
            o["_tag"] = t.tag;
            o["_count"] = t.count;
            arr.push_back(o);
        }
        return RE::BSFixedString(SafeDump(arr));
    }

    std::int32_t AnimDb_TotalEnabled(RE::StaticFunctionTag*)
    {
        return AnimationDB::TotalEnabledCount();
    }

    std::int32_t AnimDb_TotalCount(RE::StaticFunctionTag*)
    {
        return AnimationDB::TotalCount();
    }

    RE::BSFixedString AnimDb_GetByRegistry(RE::StaticFunctionTag*, RE::BSFixedString registry)
    {
        auto row = AnimationDB::GetByRegistry(registry.c_str() ? registry.c_str() : "");
        if (!row)
            return RE::BSFixedString("");
        return RE::BSFixedString(SafeDump(RowToJson(*row)));
    }

    RE::BSFixedString AnimDb_GetStageDescription(RE::StaticFunctionTag*, RE::BSFixedString registry,
        std::int32_t stage)
    {
        return RE::BSFixedString(
            AnimationDB::GetStageDescription(registry.c_str() ? registry.c_str() : "", stage));
    }

    RE::BSFixedString AnimDb_GetTransition(RE::StaticFunctionTag*, RE::BSFixedString registry,
        std::int32_t from_stage, std::int32_t to_stage)
    {
        return RE::BSFixedString(AnimationDB::GetTransition(
            registry.c_str() ? registry.c_str() : "", from_stage, to_stage));
    }

    RE::BSFixedString AnimDb_SubstituteActors(RE::StaticFunctionTag*, RE::BSFixedString desc,
        RE::BSFixedString actors_json)
    {
        const auto names = ParseActorNames(actors_json.c_str(), "AnimDb_SubstituteActors");
        std::string result = AnimationDB::SubstituteActors(desc.c_str() ? desc.c_str() : "", names);
        if (result.find("{{sl.actors.") != std::string::npos) {
            webui_log::warn("AnimDb_SubstituteActors: tokens left after substitution | names={} json='{}' desc='{}'",
                names.size(), actors_json.c_str() ? actors_json.c_str() : "(null)",
                desc.c_str() ? desc.c_str() : "(null)");
        }
        return RE::BSFixedString(result);
    }

    RE::BSFixedString AnimDb_GetStagesJson(RE::StaticFunctionTag*, RE::BSFixedString registry,
        std::int32_t stage_count, RE::BSFixedString actors_json, std::int32_t current_stage)
    {
        const auto names = ParseActorNames(actors_json.c_str(), "AnimDb_GetStagesJson");
        const auto templates = AnimationDB::GetAllStageDescriptions(
            registry.c_str() ? registry.c_str() : "", stage_count);
        nlohmann::json arr = nlohmann::json::array();
        std::string carried; // _preview falls back to the nearest earlier stage, as GetThreadStageDescription did
        for (size_t i = 0; i < templates.size(); ++i) {
            const int stage = static_cast<int>(i) + 1;
            if (!templates[i].empty())
                carried = templates[i];
            nlohmann::json st;
            st["_stage"] = stage;
            st["_template"] = templates[i];
            st["_preview"] = AnimationDB::SubstituteActors(carried, names);
            st["_current"] = (stage == current_stage) ? 1 : 0;
            arr.push_back(std::move(st));
        }
        return RE::BSFixedString(SafeDump(arr));
    }

    bool AnimDb_SaveAnimLocal(RE::StaticFunctionTag*, RE::BSFixedString registry, RE::BSFixedString json)
    {
        try {
            auto j = nlohmann::json::parse(json.c_str() ? json.c_str() : "{}");
            return AnimationDB::SaveAnimLocal(registry.c_str() ? registry.c_str() : "", j);
        } catch (...) {
            return false;
        }
    }

    RE::BSFixedString AnimDb_ResolveTags(RE::StaticFunctionTag*, RE::BSFixedString tags_csv,
        std::int32_t actor_count, RE::BSFixedString synonyms)
    {
        return RE::BSFixedString(AnimationDB::ResolveTags(tags_csv.c_str() ? tags_csv.c_str() : "", actor_count,
            AnimationDB::ParseSynonymMode(synonyms.c_str() ? synonyms.c_str() : "")));
    }

    bool AnimDb_CsvHasTag(RE::StaticFunctionTag*, RE::BSFixedString tags_csv, RE::BSFixedString tag)
    {
        return AnimationDB::CsvHasTag(
            tags_csv.c_str() ? tags_csv.c_str() : "",
            tag.c_str() ? tag.c_str() : "");
    }

    // Per position: 1 when strictly more of the registries default that position to clothed than
    // not, else 0 (tie -> undressed). Missing rows / positions count as undressed, matching
    // SkyrimNet_SexLab_AnimDb.GetClothed's default.
    std::vector<std::int32_t> AnimDb_ClothedMajority(RE::StaticFunctionTag*,
        std::vector<RE::BSFixedString> registries, std::int32_t position_count)
    {
        const auto n = position_count > 0 ? static_cast<std::size_t>(position_count) : 0;
        std::vector<std::int32_t> dressed(n, 0);
        std::int32_t total = 0;
        for (const auto& reg : registries) {
            if (!reg.c_str() || !reg.c_str()[0])
                continue;
            ++total;
            auto row = AnimationDB::GetByRegistry(reg.c_str());
            if (!row)
                continue;
            for (std::size_t i = 0; i < n && i < row->pos_clothed.size(); ++i) {
                if (row->pos_clothed[i] == 1)
                    ++dressed[i];
            }
        }
        std::vector<std::int32_t> out(n, 0);
        for (std::size_t i = 0; i < n; ++i)
            out[i] = dressed[i] * 2 > total ? 1 : 0;
        return out;
    }

    bool Register_AnimationDB_Functions(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm) {
            webui_log::error("Couldn't get Papyrus Virtual Machine.");
            return false;
        }
        constexpr std::string_view scriptName = "SkyrimNet_SexLab_AnimDb";

        a_vm->RegisterFunction("AnimDb_Open", scriptName, AnimDb_Open);
        a_vm->RegisterFunction("AnimDb_BeginSync", scriptName, AnimDb_BeginSync);
        a_vm->RegisterFunction("AnimDb_PushAnimBatch", scriptName, AnimDb_PushAnimBatch);
        a_vm->RegisterFunction("AnimDb_EndSync", scriptName, AnimDb_EndSync);
        a_vm->RegisterFunction("AnimDb_SyncFromSlal", scriptName, AnimDb_SyncFromSlal);
        a_vm->RegisterFunction("AnimDb_IsSlalSyncRunning", scriptName, AnimDb_IsSlalSyncRunning, true);
        a_vm->RegisterFunction("AnimDb_SlalSummary", scriptName, AnimDb_SlalSummary, true);
        a_vm->RegisterFunction("AnimDb_SyncFromSlsb", scriptName, AnimDb_SyncFromSlsb);
        a_vm->RegisterFunction("AnimDb_IsSlsbSyncRunning", scriptName, AnimDb_IsSlsbSyncRunning, true);
        a_vm->RegisterFunction("AnimDb_SlsbSummary", scriptName, AnimDb_SlsbSummary, true);
        a_vm->RegisterFunction("AnimDb_SlsbRegistryEnabled", scriptName, AnimDb_SlsbRegistryEnabled, true);
        a_vm->RegisterFunction("AnimDb_GetPlaybackJson", scriptName, AnimDb_GetPlaybackJson, true);
        a_vm->RegisterFunction("AnimDb_SetEnabled", scriptName, AnimDb_SetEnabled);
        a_vm->RegisterFunction("AnimDb_RecordPlay", scriptName, AnimDb_RecordPlay);
        a_vm->RegisterFunction("AnimDb_QueryTopNAnims", scriptName, AnimDb_QueryTopNAnims, true);
        a_vm->RegisterFunction("AnimDb_QueryTopNTags", scriptName, AnimDb_QueryTopNTags, true);
        a_vm->RegisterFunction("AnimDb_TotalEnabled", scriptName, AnimDb_TotalEnabled, true);
        a_vm->RegisterFunction("AnimDb_TotalCount", scriptName, AnimDb_TotalCount, true);
        a_vm->RegisterFunction("AnimDb_GetByRegistry", scriptName, AnimDb_GetByRegistry, true);
        a_vm->RegisterFunction("AnimDb_GetStageDescription", scriptName, AnimDb_GetStageDescription, true);
        a_vm->RegisterFunction("AnimDb_GetTransition", scriptName, AnimDb_GetTransition, true);
        a_vm->RegisterFunction("AnimDb_SubstituteActors", scriptName, AnimDb_SubstituteActors, true);
        a_vm->RegisterFunction("AnimDb_GetStagesJson", scriptName, AnimDb_GetStagesJson, true);
        a_vm->RegisterFunction("AnimDb_SaveAnimLocal", scriptName, AnimDb_SaveAnimLocal);
        a_vm->RegisterFunction("AnimDb_ResolveTags", scriptName, AnimDb_ResolveTags, true);
        a_vm->RegisterFunction("AnimDb_CsvHasTag", scriptName, AnimDb_CsvHasTag, true);
        a_vm->RegisterFunction("AnimDb_ClothedMajority", scriptName, AnimDb_ClothedMajority, true);

        webui_log::info("Successfully registered Papyrus functions for {}", scriptName);
        return true;
    }
}
