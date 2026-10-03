#pragma once

#include <cstdint>
#include <filesystem>
#include <mutex>
#include <optional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include <nlohmann/json.hpp>

namespace AnimationDB
{
    struct AnimRow
    {
        std::string registry;
        std::string name;
        int enabled = 1;
        int source = 0;
        int position_count = 0;
        int stage_count = 0;
        int males = 0;
        int females = 0;
        int male_creatures = 0;
        int female_creatures = 0;
        int has_creature = 0;
        std::string race_type;
        std::vector<int> pos_genders;
        std::vector<std::string> pos_race_keys;
        std::vector<std::string> tags;
        std::vector<int> pos_no_orgasm;
        std::vector<std::string> pos_speaking_modifiers; // CSV-per-position (stage 1 resolved; Papyrus compat)
        std::vector<int> pos_clothed;                    // 0/1 per position (stage 1 resolved)
        std::unordered_map<int, std::string> stage_descriptions; // resolved (carry-forward)
        std::vector<int> stage_has_description;
        /// Per-stage resolved speaking: stage → vector of CSV strings (one per actor).
        std::unordered_map<int, std::vector<std::string>> stage_speaking;
        /// Per-stage resolved clothed: stage → 0/1 per actor.
        std::unordered_map<int, std::vector<int>> stage_clothed;
        /// Per-stage resolved SNSL tags: stage → tag list.
        std::unordered_map<int, std::vector<std::string>> stage_tags;
        nlohmann::json transitions = nlohmann::json::object();
        std::vector<std::string> file_tags; // SNSL animation-level tags (not SexLab registry tags)
        std::string creator;
        std::int64_t sync_gen = 0;
    };

    /// Which synonyms-*.json cluster set expands must/suppress tags. None = literal tags only.
    enum class SynonymMode { None, Strict, Broad };

    struct FilterSpec
    {
        std::optional<int> actor_count;
        std::vector<std::string> must_tags;
        std::vector<std::string> suppress_tags;
        bool require_all = true;
        int creature = 0;
        bool enabled_only = true;
        bool position_match = false;
        std::vector<int> pos_genders;
        std::vector<std::string> pos_race_keys;
        int has_description = 0;
        bool gender_match = false;
        int males = -1;
        int females = -1;
        int male_creatures = -1;
        int female_creatures = -1;
        std::string name_contains; // lowercase; case-insensitive substring of AnimRow::name
        SynonymMode synonyms = SynonymMode::Broad;
        bool shuffle = false; // QueryTopNAnims: random order before truncating to n
        /// Scene-setting `tags_any`: row must match ≥1 (each widened to its cluster).
        std::vector<std::string> any_tags;
        /// Scene-setting `tags_prefer`: QueryTopNAnims returns only rows matching ≥1 when any do.
        std::vector<std::string> prefer_tags;
        /// Scene-setting `exclude_settings`: a row matching any of these tag filters is dropped.
        std::vector<FilterSpec> exclude_filters;
    };

    /// Tag-filter keys of one scenes/<name>.json (default.json merged under it; the named file wins per key).
    struct SceneSettingFilter
    {
        bool found = false;
        std::optional<SynonymMode> synonyms;
        std::vector<std::string> tags;
        std::vector<std::string> tags_suppress;
        std::vector<std::string> tags_any;
        std::vector<std::string> tags_prefer;
        std::vector<std::string> tags_suppress_unless_bound;
        /// `assume_bound`: treat the cast as bound (tags_suppress_unless_bound never applies).
        bool assume_bound = false;
        std::vector<std::string> exclude_settings;
    };

    struct TagCount
    {
        std::string tag;
        int count = 0;
    };

    bool Open();
    void Close();
    bool IsOpen();

    std::int64_t BeginSync(bool force_rebuild);
    bool PushAnim(const nlohmann::json& anim);
    int PushAnimBatch(const nlohmann::json& arr);
    bool EndSync();

    std::vector<AnimRow> QueryTopNAnims(const FilterSpec& spec, int n);
    std::vector<TagCount> QueryTopNTags(const FilterSpec& spec, int n);
    int TotalEnabledCount();
    int TotalCount();

    std::optional<AnimRow> GetByRegistry(const std::string& registry);
    std::string GetStageDescription(const std::string& registry, int stage);
    /// Raw templates for stages 1..stage_count in one lock/lookup (empty string where a stage has none).
    std::vector<std::string> GetAllStageDescriptions(const std::string& registry, int stage_count);
    std::string GetTransition(const std::string& registry, int from_stage, int to_stage);
    std::string SubstituteActors(const std::string& desc, const std::vector<std::string>& actor_names);
    bool SaveAnimLocal(const std::string& registry, const nlohmann::json& payload);

    std::vector<int> InferOrgasmExpected(int position_count, const std::vector<int>& pos_genders,
        const std::unordered_set<std::string>& tags,
        const std::optional<std::vector<int>>& file_override);

    void InferSpeakingModifiers(const std::vector<int>& pos_no_orgasm,
        const std::unordered_set<std::string>& tags,
        std::vector<std::string>& out_csv_per_pos);

    std::string ToLower(std::string s);
    int ParseHasDescriptionMode(const nlohmann::json& j);
    bool RowHasAnyDescription(const AnimRow& row);
    /// Sanitize aliases + lowercase; empty if blank after trim.
    std::string SanitizeTag(std::string tag);
    /// Split CSV, sanitize each, dedupe preserving order.
    std::vector<std::string> ParseSanitizeTagsCsv(const std::string& csv);
    /// Largest front-preferring subset matching ≥1 enabled anim. Empty input → "". actor_count≤0 ignores count.
    /// Returns the requested words (not their synonyms); `mode` only widens what counts as a match.
    /// `base` (optional) adds a scene setting's constraints (suppress / any / exclude / fixed must) to every probe.
    std::string ResolveTags(const std::string& tags_csv, int actor_count, SynonymMode mode = SynonymMode::Broad,
        const FilterSpec* base = nullptr);
    /// resolved_csv plus each `extra` tag (in order) that still leaves ≥1 enabled anim with all tags.
    /// Keeps resolved_csv first (narration method = first tag). Use for optional tags (DD) instead of
    /// ResolveTags, whose subset search can drop the method in favour of the extras.
    std::string AppendMatchingTags(const std::string& resolved_csv, const std::vector<std::string>& extra,
        int actor_count, SynonymMode mode = SynonymMode::Broad, const FilterSpec* base = nullptr);

    /// scenes/<name>.json over scenes/default.json (cached; cleared by LoadSynonyms). Empty name → default only.
    SceneSettingFilter LoadSceneSettingFilter(const std::string& name);
    /// Adds a setting's tags_any / tags_prefer / exclude_settings to `spec`, plus tags_suppress_unless_bound
    /// when `bound` is false. Does not touch must/suppress (callers already send the setting's tags/suppress).
    void ApplySceneSetting(FilterSpec& spec, const std::string& name, bool bound);
    /// Base spec for ResolveTags on a scene start: setting tags (must), tags_suppress (+ unless_bound when
    /// unbound), tags_any, exclude_settings, and its synonym mode.
    FilterSpec SceneSettingResolveBase(const std::string& name, bool bound);
    /// Parses the scene-setting filter keys shared by Papyrus and WebUI filter JSON:
    /// `_any_tags`, `_prefer_tags`, `_exclude_settings`, and `_setting` (+ `_bound`, default false).
    void ParseSceneFilterKeys(const nlohmann::json& j, FilterSpec& spec, std::optional<bool> bound_override = std::nullopt);

    /// "strict" / "none" (case-insensitive); anything else (incl. empty) → Broad.
    SynonymMode ParseSynonymMode(const std::string& s);
    /// Reload synonyms-strict.json + synonyms-broad.json from PluginDataDir(). Missing file → that mode is literal.
    void LoadSynonyms();
    /// Cluster containing `tag` under `mode` (always includes `tag` itself).
    std::vector<std::string> SynonymsOf(const std::string& tag, SynonymMode mode);
    /// True if needle (sanitized) or a member of its strict synonym cluster is an element of tags_csv.
    bool CsvHasTag(const std::string& tags_csv, const std::string& tag);

    std::filesystem::path PluginDataDir();
}
