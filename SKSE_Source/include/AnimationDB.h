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

    /// AnimRow::source for rows the C++ registry loaders store (0/1 = Papyrus-pushed rows).
    /// One owner per profile: SexLab AE → SlalLoader (kSourceSlal); SexLab P+ → SlsbLoader (kSourceSlsb) when
    /// sexlab.anim_engine.slsb_registry is on, else the Papyrus walk (BeginSync/EndSync wipe and prune every row).
    /// The loader's ReplaceRegistryRows + DropRowsExceptSource then make the table that source's only.
    constexpr int kSourceSlal = 2;
    constexpr int kSourceSlsb = 3;

    /// anim_playback JSON version the loaders write. Part of the source stamps, so a format change reparses once.
    constexpr int kPlaybackFormat = 2;
    constexpr const char* kPlaybackFormatStampKey = "@playback_format";

    /// One actor's part of one stage node (AnimEngine playback). See docs/developers/anim-engine.md §3.
    struct PlayStage
    {
        std::string event;                  // FNIS animation event (SLAL stage id; SLSB <prefix_hash><event>)
        std::string hkx;                    // Data-relative path from the FNIS list ("" when not listed)
        std::string kind;                   // FNIS line type: b / s / + / ...
        std::vector<std::string> objects;   // AnimObject EditorIDs (FNIS -o)
        std::vector<std::string> animvars;  // FNIS -AV<var>
        bool acyclic = false;               // FNIS -a
        float fwd = 0.f, side = 0.f, up = 0.f, rot = 0.f;
        bool silent = false, open_mouth = false, strap_on = false;
        int sos = 0;
        bool fnis = false;                  // event found in an FNIS list
        std::string interact_site = "auto"; // V A M H LH RH none auto
        int interact_target = -1;           // 0-based position, -1 = any
        std::string interact_src;           // ppa / anidata / ""
        std::string anim_obj;               // SLSB position anim_obj (AnimObject EditorID), "" for SLAL
        bool climax = false;                // SLSB position extra.climax
        int schlong = 0;                    // SLSB schlong angle
        float scale = 1.f;                  // SLSB position scale
    };

    struct PlayPosition
    {
        std::string type;   // SLAL actor type (Male, Female, Creature, CreatureMale, CreatureFemale); "" for SLSB
        int gender = 0;     // 0 M (or futa), 1 F, 2 creature (male), 3 creature female
        bool futa = false;  // SLSB sex.futa
        std::string race;   // creature race key ("" for humans)
        int add_cum = -1;
        std::vector<PlayStage> stages; // parallel to PlaybackData::nodes
    };

    /// One stage of the scene graph. SLAL animations are a linear graph ("1" → "2" → … → sink).
    struct PlayNode
    {
        std::string id;                 // SLAL "1".."N"; SLSB stage id
        int n = 0;                      // legacy stage number (1-based file order = P+ GetLegacyStageNum)
        std::vector<std::string> dest;  // next node ids; empty = sink (last stage)
        std::vector<std::string> tags;  // SLSB stage tags (lowercase); empty for SLAL
        float fixed_len = 0.f;          // SLSB extra.fixed_len seconds (0 = none)
        float timer = 0.f;              // SLAL stages[n].timer seconds (0 = config default)
        std::string sound;              // SLAL stages[n].sound
    };

    struct PlaybackData
    {
        std::string format;             // "slal" / "slsb"
        std::string registry, slal_id, pack, name, sound, creature_race;
        int stage_count = 0;
        std::string root;
        std::vector<PlayNode> nodes;
        std::vector<PlayPosition> positions;
        float furniture_offset[4] = { 0.f, 0.f, 0.f, 0.f }; // SLSB scene furniture offset fwd, side, up, rot
        int missing_fnis = 0;
        int missing_hkx = 0;

        /// Index into nodes, -1 when unknown.
        int NodeIndex(const std::string& id) const;
    };

    /// Prepared by the registry loaders for ReplaceRegistryRows.
    struct PlaybackRow
    {
        std::string registry, slal_id /* SLAL id or SLSB scene id */, pack, src_json;
        std::string json; // PlaybackData as the stored JSON blob
        int missing_fnis = 0;
        int missing_hkx = 0;
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
        /// Parallel to pos_genders: 1 = intersex actor (fills a male or a female position).
        std::vector<int> pos_intersex;
        std::vector<std::string> pos_race_keys;
        int has_description = 0;
        bool gender_match = false;
        int males = -1;
        int females = -1;
        /// gender_match: intersex actors, not in males / females; each stands in for either.
        int intersex = 0;
        int male_creatures = -1;
        int female_creatures = -1;
        std::string name_contains; // lowercase; case-insensitive substring of AnimRow::name
        bool favorites_only = false; // only registries in the favorites table
        SynonymMode synonyms = SynonymMode::Broad;
        bool shuffle = false; // QueryTopNAnims: random order before truncating to n
        /// QueryTopNAnims: described → cast-gender tier → least played → random, before truncating to n.
        /// Wins over shuffle.
        bool rank = false;
        /// rank: the cast's SexLab genders (0 m, 1 f, 2 m creature, 3 f creature) in cast order.
        /// Ranks rows (position match, then gender counts, then the rest); never filters them.
        std::vector<int> rank_pos_genders;
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
    /// Papyrus binding: a batch's first parse failed. Returns that count for the current sync.
    int NoteBatchParseError();
    /// Papyrus binding: a batch could not be parsed even after unescaping \"; its rows are lost.
    void NoteBatchDropped();
    bool EndSync();

    /// Registry loaders: replaces every row of `source` (registry rows go through PushAnim, so anidata, orgasm and
    /// speaking inference apply) plus their anim_playback rows. Rows of other sources are untouched. force:
    /// rebuild rows even when unchanged. Returns the number of registry rows stored.
    int ReplaceRegistryRows(int source, const std::vector<nlohmann::json>& rows, const std::vector<PlaybackRow>& playback,
        bool force);
    /// Deletes every row (and playback row) not of `source`, e.g. rows the old SexLab registry walk pushed.
    /// Returns the count.
    int DropRowsExceptSource(int source);
    /// playback_sources: path → "mtime:size" stamps of the files the last load of `source` read.
    std::unordered_map<std::string, std::string> GetSourceStamps(int source);
    void SetSourceStamps(int source, const std::unordered_map<std::string, std::string>& stamps);
    /// anim_playback rows whose registry row is of `source`.
    int PlaybackRowCount(int source);
    /// Stored playback JSON for a registry ("" when none).
    std::string GetPlaybackJson(const std::string& registry);
    std::optional<PlaybackData> GetPlayback(const std::string& registry);
    /// User enable toggle for registry-loader rows (anim_enabled table; survives rebuilds). Default enabled.
    bool SetAnimEnabled(const std::string& registry, bool enabled);

    std::vector<AnimRow> QueryTopNAnims(const FilterSpec& spec, int n);
    std::vector<TagCount> QueryTopNTags(const FilterSpec& spec, int n);
    int TotalEnabledCount();
    int TotalCount();

    std::optional<AnimRow> GetByRegistry(const std::string& registry);
    bool IsFavorite(const std::string& registry);
    /// Persists to the favorites table (survives animation resync/rebuild).
    bool SetFavorite(const std::string& registry, bool favorite);
    /// Times a scene has played this animation (play_counts table; survives resync/rebuild).
    int PlayCount(const std::string& registry);
    /// Adds one play for registry. Called once per new animation a scene plays.
    bool RecordPlay(const std::string& registry);
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
