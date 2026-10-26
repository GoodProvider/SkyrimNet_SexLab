#include "SlsbLoader.h"

#include "AnimSources.h"
#include "AnimationDB.h"
#include "JsonUtil.h"
#include "Profiler.h"
#include "WebUI_Log.h"

#include <atomic>
#include <chrono>
#include <fstream>
#include <mutex>
#include <thread>
#include <unordered_map>
#include <unordered_set>

namespace SlsbLoader
{
    namespace
    {
        namespace fs = std::filesystem;
        using AnimSources::Lower;
        using AnimSources::Trim;

        std::atomic<bool> g_running{ false };
        std::atomic<bool> g_queued{ false };
        std::atomic<bool> g_queued_force{ false };
        std::atomic<bool> g_queued_drop{ false };
        std::mutex g_summary_mutex;
        std::string g_summary = "not run";

        void SetSummary(std::string s)
        {
            std::lock_guard lock(g_summary_mutex);
            g_summary = std::move(s);
        }

        std::string StrOr(const nlohmann::json& j, const char* k)
        {
            return j.is_object() && j.contains(k) && j[k].is_string() ? j[k].get<std::string>() : std::string();
        }

        float NumOr(const nlohmann::json& j, const char* k, float def = 0.f)
        {
            return j.is_object() && j.contains(k) && j[k].is_number() ? j[k].get<float>() : def;
        }

        bool BoolOr(const nlohmann::json& j, const char* k)
        {
            return j.is_object() && j.contains(k) && j[k].is_boolean() && j[k].get<bool>();
        }

        const nlohmann::json& ObjOr(const nlohmann::json& j, const char* k)
        {
            static const nlohmann::json empty = nlohmann::json::object();
            return j.is_object() && j.contains(k) && j[k].is_object() ? j[k] : empty;
        }

        bool IsHuman(const nlohmann::json& pos)
        {
            const auto race = StrOr(pos, "race");
            return race.empty() || race == "Human";
        }

        /// 1.6x coding, as SkyrimNet_SexLab_PPlus.PositionGenders: human male / futa 0, female 1; creature 2,
        /// female-only creature 3.
        int GenderOf(const nlohmann::json& pos)
        {
            const auto& sex = ObjOr(pos, "sex");
            if (IsHuman(pos))
                return BoolOr(sex, "male") || BoolOr(sex, "futa") ? 0 : 1;
            return BoolOr(sex, "female") && !BoolOr(sex, "male") ? 3 : 2;
        }

        /// .slr header: u8 version, 7 bytes, u8 length + pack_name (equals the .slsb.json pack_name).
        std::string SlrPackName(const fs::path& p)
        {
            std::ifstream in(p, std::ios::binary);
            char head[9 + 255]{};
            in.read(head, sizeof(head));
            const auto got = in.gcount();
            if (got < 10)
                return {};
            const auto len = static_cast<unsigned char>(head[8]);
            return std::string(head + 9, head + 9 + std::min<std::streamsize>(len, got - 9));
        }

        struct Stats
        {
            int packs = 0, scenes = 0, stages = 0, branching = 0, missing_fnis = 0, missing_hkx = 0, duplicates = 0;
            int bad_files = 0;
        };

        /// One SLSB scene → AnimDB row (the keys BuildAnimJson_PPlus pushes) + playback v2 graph.
        void BuildScene(const std::string& sid, const nlohmann::json& sc, const std::string& pack,
            const std::string& prefix, const std::string& src, const AnimSources::FnisIndex& fnis,
            nlohmann::json& row, AnimationDB::PlaybackRow& pb, Stats& st, int& warned)
        {
            const nlohmann::json& stages = sc["stages"];
            const nlohmann::json& graph = ObjOr(sc, "graph");
            std::string root = StrOr(sc, "root");
            const nlohmann::json* first = &stages[0];
            for (const auto& s : stages) {
                if (!root.empty() && StrOr(s, "id") == root) {
                    first = &s;
                    break;
                }
            }
            if (root.empty())
                root = StrOr(*first, "id");
            const nlohmann::json poss = first->contains("positions") && (*first)["positions"].is_array()
                                            ? (*first)["positions"]
                                            : nlohmann::json::array();

            std::vector<int> genders;
            std::vector<std::string> races;
            std::vector<bool> futa;
            int counts[4] = { 0, 0, 0, 0 };
            std::string race_type;
            for (const auto& p : poss) {
                const int g = GenderOf(p);
                genders.push_back(g);
                futa.push_back(BoolOr(ObjOr(p, "sex"), "futa"));
                ++counts[g];
                // SLSB race display name. TODO(parity): P+ GetRaceKeyPositionA may return its race key instead.
                const std::string rk = IsHuman(p) ? std::string() : StrOr(p, "race");
                if (race_type.empty() && !rk.empty())
                    race_type = rk; // BuildAnimJson_PPlus: first creature key
                races.push_back(rk);
            }
            const int pos_count = static_cast<int>(genders.size());

            // Union of stage tags in stage order: SLSB copies the SLAL animation tags onto every stage and adds
            // per-stage acts (vaginal, blowjob, …), so the union is the SLAL animation-level set.
            std::vector<std::string> tags;
            std::unordered_set<std::string> seen;
            for (const auto& s : stages) {
                for (const auto& t : s.value("tags", nlohmann::json::array())) {
                    if (!t.is_string())
                        continue;
                    const auto lt = Lower(Trim(t.get<std::string>()));
                    if (!lt.empty() && seen.insert(lt).second)
                        tags.push_back(lt);
                }
            }

            row = nlohmann::json::object();
            row["_registry"] = sid;
            row["_case"] = 1;
            row["_name"] = StrOr(sc, "name");
            row["_position_count"] = pos_count;
            row["_stage_count"] = static_cast<int>(stages.size());
            row["_males"] = counts[0];
            row["_females"] = counts[1];
            row["_male_creatures"] = counts[2];
            row["_female_creatures"] = counts[3];
            row["_has_creature"] = counts[2] + counts[3] > 0 ? 1 : 0;
            row["_race_type"] = race_type;
            row["_pos_genders"] = genders;
            row["_pos_race_keys"] = races;
            row["_tags"] = tags;

            nlohmann::json j;
            j["v"] = AnimationDB::kPlaybackFormat;
            j["format"] = "slsb";
            j["scene_id"] = sid;
            j["pack"] = pack;
            j["name"] = StrOr(sc, "name");
            j["stage_count"] = static_cast<int>(stages.size());
            j["root"] = root;
            const auto& furn = ObjOr(sc, "furniture");
            const auto& foff = ObjOr(furn, "offset");
            j["furniture"] = { { "types", furn.value("furni_types", nlohmann::json::array()) },
                { "allow_bed", BoolOr(furn, "allow_bed") },
                { "offset", { NumOr(foff, "x"), NumOr(foff, "y"), NumOr(foff, "z"), NumOr(foff, "r") } } };

            bool branches = false;
            int missing_fnis = 0, missing_hkx = 0;
            nlohmann::json jnodes = nlohmann::json::array();
            std::vector<nlohmann::json> jpos_stages(pos_count, nlohmann::json::array());
            int n = 0;
            for (const auto& s : stages) {
                ++n;
                const std::string nid = StrOr(s, "id");
                const auto& g = ObjOr(graph, nid.c_str());
                std::vector<std::string> dest;
                for (const auto& d : g.value("dest", nlohmann::json::array())) {
                    if (d.is_string())
                        dest.push_back(d.get<std::string>());
                }
                branches = branches || dest.size() > 1;
                std::vector<std::string> ntags;
                for (const auto& t : s.value("tags", nlohmann::json::array())) {
                    if (t.is_string())
                        ntags.push_back(Lower(Trim(t.get<std::string>())));
                }
                jnodes.push_back({ { "id", nid }, { "n", n }, { "dest", dest }, { "tags", ntags },
                    { "fixed_len", NumOr(ObjOr(s, "extra"), "fixed_len") } });

                const nlohmann::json sp = s.contains("positions") && s["positions"].is_array() ? s["positions"]
                                                                                               : nlohmann::json::array();
                for (int p = 0; p < pos_count; ++p) {
                    const nlohmann::json& pos = p < static_cast<int>(sp.size()) ? sp[p] : nlohmann::json::object();
                    std::string ev;
                    if (pos.contains("event") && pos["event"].is_array() && !pos["event"].empty() &&
                        pos["event"][0].is_string())
                        ev = prefix + pos["event"][0].get<std::string>(); // SLSB FNIS lists: <prefix_hash><event>
                    const AnimSources::FnisEntry* fe = ev.empty() ? nullptr : fnis.Find(ev);
                    if (!fe) {
                        ++missing_fnis;
                        if (warned < 20) {
                            ++warned;
                            webui_log::warn("SlsbLoader: {} '{}' stage {} position {} event '{}' is in no FNIS list "
                                            "(pack {})",
                                sid, StrOr(sc, "name"), n, p + 1, ev, pack);
                        }
                    } else if (!fe->hkx_loose) {
                        ++missing_hkx;
                    }
                    const auto& off = ObjOr(pos, "offset");
                    const auto& ex = ObjOr(pos, "extra");
                    nlohmann::json e;
                    e["event"] = ev;
                    e["hkx"] = fe ? fe->hkx : "";
                    e["kind"] = fe ? fe->kind : "";
                    e["objects"] = fe ? fe->objects : std::vector<std::string>{};
                    e["animvars"] = fe ? fe->animvars : std::vector<std::string>{};
                    e["acyclic"] = fe && fe->acyclic;
                    // P+ OffsetCoords: [0] forward, [1] side (rz + 90°), [2] up, [3] rotate.
                    e["fwd"] = NumOr(off, "x");
                    e["side"] = NumOr(off, "y");
                    e["up"] = NumOr(off, "z");
                    e["rot"] = NumOr(off, "r");
                    e["fnis"] = fe != nullptr;
                    e["anim_obj"] = StrOr(pos, "anim_obj");
                    e["climax"] = BoolOr(ex, "climax");
                    e["schlong"] = pos.contains("schlong") && pos["schlong"].is_number() ? pos["schlong"].get<int>() : 0;
                    e["scale"] = NumOr(pos, "scale", 1.f);
                    e["interact"] = { { "site", "auto" }, { "target", -1 }, { "src", "" } };
                    jpos_stages[p].push_back(std::move(e));
                    ++st.stages;
                }
            }
            if (branches)
                ++st.branching;
            j["nodes"] = std::move(jnodes);
            nlohmann::json jpos = nlohmann::json::array();
            for (int p = 0; p < pos_count; ++p) {
                jpos.push_back({ { "type", "" }, { "gender", genders[p] }, { "futa", static_cast<bool>(futa[p]) },
                    { "race", races[p] }, { "add_cum", -1 }, { "stages", std::move(jpos_stages[p]) } });
            }
            j["positions"] = std::move(jpos);
            j["missing_fnis"] = missing_fnis;
            j["missing_hkx"] = missing_hkx;
            st.missing_fnis += missing_fnis;
            st.missing_hkx += missing_hkx;

            pb.registry = sid;
            pb.slal_id = sid;
            pb.pack = pack;
            pb.src_json = src;
            pb.json = SafeDump(j);
            pb.missing_fnis = missing_fnis;
            pb.missing_hkx = missing_hkx;
        }
    }

    int Run(bool force, bool drop_legacy)
    {
        SNSL_PROF("slsb.load");
        const auto t0 = std::chrono::steady_clock::now();
        if (!AnimationDB::IsOpen() && !AnimationDB::Open())
            return 0;
        const fs::path data = AnimSources::GameDataDir();
        const fs::path registry_dir = data / "SKSE" / "SexLab" / "Registry";

        std::vector<fs::path> packs;
        for (auto& p : AnimSources::JsonFilesIn(registry_dir / "Source")) {
            if (Lower(p.filename().string()).ends_with(".slsb.json"))
                packs.push_back(p);
        }
        std::vector<fs::path> slr_files;
        std::error_code ec;
        if (fs::is_directory(registry_dir, ec)) {
            for (const auto& ent : fs::directory_iterator(registry_dir, ec)) {
                if (ent.is_regular_file(ec) && Lower(ent.path().extension().string()) == ".slr")
                    slr_files.push_back(ent.path());
            }
        }
        const std::vector<fs::path> lists = AnimSources::FindFnisLists(data);

        std::unordered_map<std::string, std::string> stamps;
        auto stamp_all = [&stamps](const std::vector<fs::path>& group) {
            for (const auto& p : group)
                stamps[Lower(p.generic_string())] = AnimSources::Stamp(p);
        };
        stamp_all(packs);
        stamp_all(slr_files);
        stamp_all(lists);
        stamps[AnimationDB::kPlaybackFormatStampKey] = std::to_string(AnimationDB::kPlaybackFormat);
        constexpr int kSource = AnimationDB::kSourceSlsb;
        if (!force && AnimationDB::PlaybackRowCount(kSource) > 0 && stamps == AnimationDB::GetSourceStamps(kSource)) {
            const auto s = std::format("unchanged ({} packs, {} FNIS lists), skipped reparse", packs.size(), lists.size());
            webui_log::info("SlsbLoader: {}", s);
            SetSummary(s);
            if (drop_legacy)
                AnimationDB::DropRowsExceptSource(kSource);
            return -1;
        }

        Stats st;
        const AnimSources::FnisIndex fnis = AnimSources::LoadFnisIndex(data, lists);

        std::vector<std::string> order;
        std::unordered_map<std::string, std::pair<nlohmann::json, AnimationDB::PlaybackRow>> built;
        std::unordered_set<std::string> json_packs;
        int warned = 0;
        for (const auto& f : packs) {
            std::string text;
            if (!AnimSources::ReadText(f, text)) {
                ++st.bad_files;
                continue;
            }
            auto j = nlohmann::json::parse(text, nullptr, false, true);
            if (j.is_discarded() || !j.is_object() || !j.contains("scenes") || !j["scenes"].is_object()) {
                ++st.bad_files;
                webui_log::warn("SlsbLoader: {} is not an SLSB project json", f.filename().string());
                continue;
            }
            ++st.packs;
            std::string pack = StrOr(j, "pack_name");
            if (pack.empty()) {
                pack = f.filename().string();
                pack.resize(pack.size() - std::string(".slsb.json").size());
            }
            json_packs.insert(Lower(pack));
            const std::string prefix = StrOr(j, "prefix_hash");
            for (const auto& [key, sc] : j["scenes"].items()) {
                if (!sc.is_object() || !sc.contains("stages") || !sc["stages"].is_array() || sc["stages"].empty())
                    continue;
                std::string sid = StrOr(sc, "id");
                if (sid.empty())
                    sid = key;
                nlohmann::json row;
                AnimationDB::PlaybackRow pb;
                BuildScene(sid, sc, pack, prefix, f.generic_string(), fnis, row, pb, st, warned);
                if (built.contains(sid)) {
                    if (++st.duplicates <= 20)
                        webui_log::warn("SlsbLoader: duplicate scene id '{}' ({} replaces {})", sid, pack,
                            built[sid].second.pack);
                } else {
                    order.push_back(sid);
                }
                built[sid] = { std::move(row), std::move(pb) };
            }
        }

        // .slr files P+ loads that have no project json: their scenes stay unknown to AnimDB.
        int slr_only = 0;
        for (const auto& s : slr_files) {
            const auto name = SlrPackName(s);
            if (!name.empty() && !json_packs.contains(Lower(name))) {
                ++slr_only;
                webui_log::warn("SlsbLoader: {} (pack '{}') has no .slsb.json in Registry/Source; its scenes are not "
                                "in AnimDB",
                    s.filename().string(), name);
            }
        }

        std::vector<nlohmann::json> rows;
        std::vector<AnimationDB::PlaybackRow> playback;
        rows.reserve(order.size());
        playback.reserve(order.size());
        for (const auto& sid : order) {
            auto& b = built[sid];
            rows.push_back(std::move(b.first));
            playback.push_back(std::move(b.second));
        }
        st.scenes = static_cast<int>(rows.size());
        const int stored = AnimationDB::ReplaceRegistryRows(kSource, rows, playback, force);
        AnimationDB::SetSourceStamps(kSource, stamps);
        if (drop_legacy)
            AnimationDB::DropRowsExceptSource(kSource);

        const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - t0).count();
        const auto s = std::format(
            "packs={} scenes={} stored={} stages={} branching={} missing_fnis={} missing_hkx(not loose)={} "
            "duplicates={} slr_without_json={} fnis_lists={} fnis_events={} bad_files={} ms={}",
            st.packs, st.scenes, stored, st.stages, st.branching, st.missing_fnis, st.missing_hkx, st.duplicates, slr_only,
            fnis.lists.size(), fnis.events.size(), st.bad_files, ms);
        webui_log::info("AnimationDB: SLSB playback {}", s);
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
                    webui_log::error("SlsbLoader: load failed: {}", e.what());
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
