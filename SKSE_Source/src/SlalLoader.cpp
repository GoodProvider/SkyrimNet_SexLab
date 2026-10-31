#include "SlalLoader.h"

#include "AnimSources.h"
#include "AnimationDB.h"
#include "JsonUtil.h"
#include "Profiler.h"
#include "WebUI_Log.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <map>
#include <mutex>
#include <sstream>
#include <thread>
#include <unordered_map>
#include <unordered_set>

namespace SlalLoader
{
    namespace
    {
        namespace fs = std::filesystem;
        using AnimSources::Lower;
        using AnimSources::Trim;
        using AnimSources::ReadText;
        using AnimSources::JsonFilesIn;

        std::atomic<bool> g_running{ false };
        std::atomic<bool> g_queued{ false };
        std::atomic<bool> g_queued_force{ false };
        std::atomic<bool> g_queued_drop{ false };
        std::mutex g_summary_mutex;
        std::string g_summary = "not run";

        // ---- PPA tags -----------------------------------------------------------------------------------

        struct PpaTarget
        {
            std::string site; // V A M H LH RH none
            int target = -1;  // 0-based
        };

        struct PpaAnim
        {
            bool manual = false;
            std::map<int, std::map<int, PpaTarget>> stages; // stage → 0-based position → target
        };

        std::string PpaSite(const std::string& code)
        {
            static const std::unordered_set<std::string> known = { "V", "A", "M", "H", "LH", "RH" };
            return known.contains(code) ? code : "none"; // "!" and unknown strings are None (PPA docs)
        }

        /// ppa-animation-tagging/*.json, keyed by lowercase animation name. PPA loads files in reverse
        /// alphabetical order and later ones win, so 0_your_custom_tags.json wins.
        std::unordered_map<std::string, PpaAnim> LoadPpaTags(const std::vector<fs::path>& files)
        {
            std::unordered_map<std::string, PpaAnim> out;
            std::vector<fs::path> order = files;
            std::reverse(order.begin(), order.end());
            for (const auto& f : order) {
                std::string text;
                if (!ReadText(f, text))
                    continue;
                auto j = nlohmann::json::parse(text, nullptr, false, true);
                if (j.is_discarded() || !j.is_object()) {
                    webui_log::warn("SlalLoader: PPA tags {} did not parse", f.filename().string());
                    continue;
                }
                for (const auto& [name, val] : j.items()) {
                    auto& a = out[Lower(Trim(name))];
                    const nlohmann::json* stg = nullptr;
                    if (val.is_array()) {
                        stg = &val;
                    } else if (val.is_object()) {
                        if (val.contains("manual") && val["manual"].is_boolean())
                            a.manual = val["manual"].get<bool>();
                        if (val.contains("stg") && val["stg"].is_array())
                            stg = &val["stg"];
                    }
                    if (!stg)
                        continue;
                    for (const auto& st : *stg) {
                        if (!st.is_object() || !st.contains("s") || !st["s"].is_number_integer())
                            continue;
                        const int s = st["s"].get<int>();
                        for (const auto& [k, v] : st.items()) {
                            if (k == "s")
                                continue;
                            const int pos = std::atoi(k.c_str()) - 1;
                            if (pos < 0 || pos > 4)
                                continue;
                            PpaTarget t;
                            if (v.is_string()) {
                                t.site = PpaSite(v.get<std::string>());
                            } else if (v.is_object()) {
                                t.site = PpaSite(v.value("action", std::string()));
                                if (v.contains("target") && v["target"].is_number_integer())
                                    t.target = v["target"].get<int>() - 1;
                            } else {
                                continue;
                            }
                            a.stages[s][pos] = t;
                        }
                    }
                }
            }
            return out;
        }

        // ---- SLAL json ----------------------------------------------------------------------------------

        int GenderOf(const std::string& type)
        {
            if (type == "Female")
                return 1;
            if (type == "Creature" || type == "CreatureMale")
                return 2;
            if (type == "CreatureFemale")
                return 3;
            return 0; // Male; SLAL registers unknown types as Male too
        }

        int CumOf(const nlohmann::json& actor)
        {
            if (!actor.contains("add_cum"))
                return -1;
            const auto& v = actor["add_cum"];
            if (v.is_number_integer())
                return v.get<int>();
            if (!v.is_string())
                return -1;
            static const std::unordered_map<std::string, int> names = { { "Vaginal", 1 }, { "Oral", 2 }, { "Anal", 3 },
                { "VaginalOral", 4 }, { "VaginalAnal", 5 }, { "OralAnal", 6 }, { "VaginalOralAnal", 7 } };
            auto it = names.find(v.get<std::string>());
            return it == names.end() ? -1 : it->second;
        }

        float NumOr(const nlohmann::json& j, const char* k, float def = 0.f)
        {
            return j.contains(k) && j[k].is_number() ? j[k].get<float>() : def;
        }

        bool BoolOr(const nlohmann::json& j, const char* k)
        {
            if (!j.contains(k))
                return false;
            if (j[k].is_boolean())
                return j[k].get<bool>();
            if (j[k].is_number())
                return j[k].get<double>() != 0.0;
            return false;
        }

        std::string StrOr(const nlohmann::json& j, const char* k)
        {
            return j.contains(k) && j[k].is_string() ? j[k].get<std::string>() : std::string();
        }

        std::string GenderString(int g)
        {
            return g == 0 ? "M" : g == 1 ? "F" : "C";
        }

        std::string Repeat(const std::string& s, int n)
        {
            std::string out;
            for (int i = 0; i < n && i < 5; ++i)
                out += s;
            return out;
        }

        struct Stats
        {
            int packs = 0, anims = 0, stages = 0, missing_fnis = 0, missing_hkx = 0, duplicates = 0, ppa = 0;
            int bad_files = 0;
        };

        /// One SLAL animation → AnimDB row JSON (same keys Papyrus pushed) + playback blob (v2: a linear stage graph).
        void BuildAnim(const nlohmann::json& a, const std::string& pack, const std::string& src,
            const AnimSources::FnisIndex& fnis, const std::unordered_map<std::string, PpaAnim>& ppa,
            nlohmann::json& row, AnimationDB::PlaybackRow& pb, Stats& st, int& warned)
        {
            const std::string id = StrOr(a, "id");
            const std::string name = StrOr(a, "name");
            const std::string creature_race = StrOr(a, "creature_race");
            const bool is_creature = a.contains("creature_race");
            const nlohmann::json actors = a.contains("actors") && a["actors"].is_array() ? a["actors"] : nlohmann::json::array();

            std::vector<int> genders;
            std::vector<std::string> races;
            int counts[4] = { 0, 0, 0, 0 };
            std::string race_type;
            for (const auto& ac : actors) {
                const int g = GenderOf(StrOr(ac, "type"));
                genders.push_back(g);
                ++counts[g];
                std::string rk = g >= 2 ? StrOr(ac, "race") : std::string();
                if (g >= 2 && rk.empty())
                    rk = creature_race;
                if (!rk.empty())
                    race_type = rk; // SexLab RaceType: last creature position's key
                races.push_back(rk);
            }
            const int pos_count = static_cast<int>(genders.size());
            int stage_count = 0;
            if (!actors.empty() && actors[0].contains("stages") && actors[0]["stages"].is_array())
                stage_count = static_cast<int>(actors[0]["stages"].size());

            // Tags: SLAL list + what sslBaseAnimation.Save() adds (gender tags, Interspecies).
            std::vector<std::string> tags;
            std::unordered_set<std::string> seen;
            auto add_tag = [&](const std::string& raw) {
                const auto t = Lower(Trim(raw));
                if (!t.empty() && seen.insert(t).second)
                    tags.push_back(t);
            };
            {
                std::stringstream ts(StrOr(a, "tags"));
                std::string t;
                while (std::getline(ts, t, ','))
                    add_tag(t);
            }
            std::string gt0, gt1;
            for (int g : genders) {
                gt0 += GenderString(g);
                gt1 = GenderString(g) + gt1;
            }
            add_tag(gt0);
            add_tag(gt1);
            const int males = counts[0], females = counts[1], creatures = counts[2] + counts[3];
            if (pos_count > 2) {
                add_tag(Repeat("F", females) + Repeat("M", males) + Repeat("C", creatures));
                add_tag(Repeat("C", creatures) + Repeat("M", males) + Repeat("F", females));
            }
            if (is_creature) {
                // Approximation of IsInterspecies (SexLab compares race-id sets): adjacent creature keys differ.
                for (int p = 1; p < pos_count; ++p) {
                    if (!races[p - 1].empty() && !races[p].empty() && Lower(races[p - 1]) != Lower(races[p])) {
                        add_tag("interspecies");
                        break;
                    }
                }
            }

            row = nlohmann::json::object();
            row["_registry"] = Lower(id);
            row["_name"] = name;
            row["_position_count"] = pos_count;
            row["_stage_count"] = stage_count;
            row["_males"] = counts[0];
            row["_females"] = counts[1];
            row["_male_creatures"] = counts[2];
            row["_female_creatures"] = counts[3];
            row["_has_creature"] = is_creature || creatures > 0 ? 1 : 0;
            row["_race_type"] = race_type;
            row["_pos_genders"] = genders;
            row["_pos_race_keys"] = races;
            row["_tags"] = tags;

            // Playback blob.
            const PpaAnim* pa = nullptr;
            if (auto it = ppa.find(Lower(Trim(name))); it != ppa.end()) {
                pa = &it->second;
                ++st.ppa;
            }
            nlohmann::json j;
            j["v"] = 2;
            j["format"] = "slal";
            j["slal_id"] = id;
            j["pack"] = pack;
            j["name"] = name;
            j["sound"] = StrOr(a, "sound");
            j["creature_race"] = creature_race;
            j["stage_count"] = stage_count;
            // Linear graph "1" → "2" → … → "N" (sink); per-stage timer / sound from SLAL stages[{number,…}].
            std::unordered_map<int, const nlohmann::json*> stage_extra;
            if (a.contains("stages") && a["stages"].is_array()) {
                for (const auto& s : a["stages"]) {
                    if (s.is_object() && s.contains("number") && s["number"].is_number_integer())
                        stage_extra[s["number"].get<int>()] = &s;
                }
            }
            nlohmann::json jnodes = nlohmann::json::array();
            for (int n = 1; n <= stage_count; ++n) {
                nlohmann::json node = { { "id", std::to_string(n) }, { "n", n }, { "tags", nlohmann::json::array() },
                    { "fixed_len", 0.f } };
                node["dest"] = n < stage_count ? nlohmann::json::array({ std::to_string(n + 1) }) : nlohmann::json::array();
                if (auto it = stage_extra.find(n); it != stage_extra.end()) {
                    const auto& s = *it->second;
                    if (s.contains("timer") && s["timer"].is_number())
                        node["timer"] = s["timer"].get<float>();
                    if (s.contains("sound") && s["sound"].is_string())
                        node["sound"] = s["sound"];
                }
                jnodes.push_back(std::move(node));
            }
            j["root"] = stage_count > 0 ? "1" : "";
            j["nodes"] = std::move(jnodes);
            int missing_fnis = 0, missing_hkx = 0;
            nlohmann::json jpos = nlohmann::json::array();
            for (int p = 0; p < pos_count; ++p) {
                const auto& ac = actors[p];
                const int g = genders[p];
                nlohmann::json jp;
                jp["type"] = StrOr(ac, "type");
                jp["gender"] = g;
                jp["race"] = races[p];
                jp["add_cum"] = (g == 1 || g == 3) ? CumOf(ac) : -1; // SLAL reads add_cum for female slots only
                nlohmann::json js = nlohmann::json::array();
                const nlohmann::json stages = ac.contains("stages") && ac["stages"].is_array() ? ac["stages"] : nlohmann::json::array();
                int sn = 0;
                for (const auto& s : stages) {
                    ++sn;
                    const std::string ev = StrOr(s, "id");
                    nlohmann::json e;
                    e["event"] = ev;
                    const AnimSources::FnisEntry* fe = fnis.Find(ev);
                    const bool found = fe != nullptr;
                    e["hkx"] = found ? fe->hkx : "";
                    e["kind"] = found ? fe->kind : "";
                    e["objects"] = found ? fe->objects : std::vector<std::string>{};
                    e["animvars"] = found ? fe->animvars : std::vector<std::string>{};
                    e["acyclic"] = found && fe->acyclic;
                    e["fwd"] = NumOr(s, "forward");
                    e["side"] = NumOr(s, "side");
                    e["up"] = NumOr(s, "up");
                    e["rot"] = NumOr(s, "rotate");
                    e["silent"] = BoolOr(s, "silent");
                    e["open_mouth"] = BoolOr(s, "open_mouth");
                    e["strap_on"] = BoolOr(s, "strap_on"); // missing = false, as SLAL's JMap.getInt
                    e["sos"] = s.contains("sos") && s["sos"].is_number() ? static_cast<int>(s["sos"].get<double>()) : 0;
                    e["fnis"] = found;
                    if (!found) {
                        ++missing_fnis;
                        if (warned < 20) {
                            ++warned;
                            webui_log::warn("SlalLoader: {} '{}' stage event '{}' is in no FNIS list (pack {})",
                                id, name, ev, pack);
                        }
                    } else if (!fe->hkx_loose) {
                        ++missing_hkx; // not a loose file; may still be inside a BSA
                    }
                    nlohmann::json ji = { { "site", "auto" }, { "target", -1 }, { "src", "" } };
                    if (pa) {
                        auto sit = pa->stages.find(sn);
                        const PpaTarget* t = nullptr;
                        if (sit != pa->stages.end()) {
                            auto pit = sit->second.find(p);
                            if (pit != sit->second.end())
                                t = &pit->second;
                        }
                        if (t)
                            ji = { { "site", t->site }, { "target", t->target }, { "src", "ppa" } };
                        else if (pa->manual)
                            ji = { { "site", "none" }, { "target", -1 }, { "src", "ppa" } };
                    }
                    e["interact"] = ji;
                    js.push_back(std::move(e));
                    ++st.stages;
                }
                jp["stages"] = std::move(js);
                jpos.push_back(std::move(jp));
            }
            j["positions"] = std::move(jpos);
            j["missing_fnis"] = missing_fnis;
            j["missing_hkx"] = missing_hkx;
            st.missing_fnis += missing_fnis;
            st.missing_hkx += missing_hkx;

            pb.registry = Lower(id);
            pb.slal_id = id;
            pb.pack = pack;
            pb.src_json = src;
            pb.json = SafeDump(j);
            pb.missing_fnis = missing_fnis;
            pb.missing_hkx = missing_hkx;
        }

        void SetSummary(std::string s)
        {
            std::lock_guard lock(g_summary_mutex);
            g_summary = std::move(s);
        }
    }

    int Run(bool force, bool drop_legacy)
    {
        SNSL_PROF("slal.load");
        const auto t0 = std::chrono::steady_clock::now();
        if (!AnimationDB::IsOpen() && !AnimationDB::Open())
            return 0;
        const fs::path data = AnimSources::GameDataDir();

        // Sources.
        std::vector<fs::path> packs = JsonFilesIn(data / "SLAnims" / "json");
        for (auto& p : JsonFilesIn(AnimationDB::PluginDataDir() / "slal"))
            packs.push_back(p);
        const std::vector<fs::path> lists = AnimSources::FindFnisLists(data);
        const std::vector<fs::path> ppa_files = JsonFilesIn(data / "SKSE" / "Plugins" / "ppa-animation-tagging");

        std::unordered_map<std::string, std::string> stamps;
        auto stamp_all = [&stamps](const std::vector<fs::path>& group) {
            for (const auto& p : group)
                stamps[Lower(p.generic_string())] = AnimSources::Stamp(p);
        };
        stamp_all(packs);
        stamp_all(lists);
        stamp_all(ppa_files);
        stamps[AnimationDB::kPlaybackFormatStampKey] = std::to_string(AnimationDB::kPlaybackFormat);
        constexpr int kSource = AnimationDB::kSourceSlal;
        if (!force && AnimationDB::PlaybackRowCount(kSource) > 0 && stamps == AnimationDB::GetSourceStamps(kSource)) {
            const auto s = std::format("unchanged ({} packs, {} FNIS lists), skipped reparse", packs.size(), lists.size());
            webui_log::info("SlalLoader: {}", s);
            SetSummary(s);
            if (drop_legacy)
                AnimationDB::DropRowsExceptSource(kSource);
            return -1;
        }

        Stats st;
        const AnimSources::FnisIndex fnis = AnimSources::LoadFnisIndex(data, lists);
        const auto ppa = LoadPpaTags(ppa_files);

        // Later files win on duplicate ids (SLAL's directory merge); keep first-seen order otherwise.
        std::vector<std::string> order;
        std::unordered_map<std::string, std::pair<nlohmann::json, AnimationDB::PlaybackRow>> built;
        int warned = 0;
        for (const auto& f : packs) {
            std::string text;
            if (!ReadText(f, text)) {
                ++st.bad_files;
                continue;
            }
            auto j = nlohmann::json::parse(text, nullptr, false, true);
            if (j.is_discarded() || !j.is_object() || !j.contains("animations") || !j["animations"].is_array()) {
                ++st.bad_files;
                webui_log::warn("SlalLoader: {} is not a SLAL animation json", f.filename().string());
                continue;
            }
            ++st.packs;
            const std::string pack = f.stem().string();
            for (const auto& a : j["animations"]) {
                if (!a.is_object() || StrOr(a, "id").empty())
                    continue;
                nlohmann::json row;
                AnimationDB::PlaybackRow pb;
                BuildAnim(a, pack, f.generic_string(), fnis, ppa, row, pb, st, warned);
                const std::string reg = pb.registry;
                if (built.contains(reg)) {
                    if (++st.duplicates <= 20)
                        webui_log::warn("SlalLoader: duplicate SLAL id '{}' ({} replaces {})", pb.slal_id, pack,
                            built[reg].second.pack);
                } else {
                    order.push_back(reg);
                }
                built[reg] = { std::move(row), std::move(pb) };
            }
        }

        std::vector<nlohmann::json> rows;
        std::vector<AnimationDB::PlaybackRow> playback;
        rows.reserve(order.size());
        playback.reserve(order.size());
        for (const auto& reg : order) {
            auto& b = built[reg];
            rows.push_back(std::move(b.first));
            playback.push_back(std::move(b.second));
        }
        st.anims = static_cast<int>(rows.size());
        const int stored = AnimationDB::ReplaceRegistryRows(kSource, rows, playback, force);
        AnimationDB::SetSourceStamps(kSource, stamps);
        if (drop_legacy)
            AnimationDB::DropRowsExceptSource(kSource);

        const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - t0).count();
        const auto s = std::format(
            "packs={} anims={} stored={} stages={} missing_fnis={} missing_hkx(not loose)={} duplicates={} "
            "fnis_lists={} fnis_events={} fnis_dup_events={} ppa_tagged={} bad_files={} ms={}",
            st.packs, st.anims, stored, st.stages, st.missing_fnis, st.missing_hkx, st.duplicates, fnis.lists.size(),
            fnis.events.size(), fnis.dups, st.ppa, st.bad_files, ms);
        webui_log::info("AnimationDB: playback {}", s);
        SetSummary(s);
        return stored;
    }

    bool StartAsync(bool force, bool drop_legacy)
    {
        bool expected = false;
        if (!g_running.compare_exchange_strong(expected, true)) {
            g_queued_force = g_queued_force || force;
            g_queued_drop = g_queued_drop || drop_legacy;
            g_queued = true;
            return false;
        }
        std::thread([force, drop_legacy]() {
            bool f = force;
            bool d = drop_legacy;
            for (;;) {
                try {
                    Run(f, d);
                } catch (const std::exception& e) {
                    webui_log::error("SlalLoader: load failed: {}", e.what());
                    SetSummary(std::string("failed: ") + e.what());
                }
                if (!g_queued.exchange(false))
                    break;
                f = g_queued_force.exchange(false);
                d = g_queued_drop.exchange(false);
            }
            g_running = false;
        }).detach();
        return true;
    }

    bool IsRunning()
    {
        return g_running;
    }

    std::string LastSummary()
    {
        std::lock_guard lock(g_summary_mutex);
        return g_summary;
    }
}
