#include "AniDescriber.h"
#include "HkxAnim.h"
#include "WebUI_Log.h"

#include "RE/Skyrim.h"
#include "RE/V/VirtualMachine.h"
#include "SKSE/SKSE.h"

#include <Windows.h>
#include <sqlite3.h>

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <initializer_list>
#include <mutex>
#include <sstream>
#include <string>
#include <unordered_map>
#include <unordered_set>

#include <nlohmann/json.hpp>

namespace AniDescriber
{
    namespace
    {
        constexpr float kIn = 12.f;
        constexpr float kOn = 25.f;
        constexpr float kSampleT[] = {0.15f, 0.5f, 0.85f};
        constexpr int kSampleN = 3;

        std::mutex g_mutex;
        sqlite3* g_db = nullptr;
        HkxAnim::Skeleton g_skel_m;
        HkxAnim::Skeleton g_skel_f;
        bool g_skel_m_ok = false;
        bool g_skel_f_ok = false;
        bool g_skel_tried = false;
        std::unordered_map<std::string, std::string> g_file_index; // lower basename → resource path
        bool g_index_ready = false;
        /// Session-only: registry|events_hash → fail reason (do not re-Analyze).
        std::unordered_map<std::string, std::string> g_fail_cache;

        std::string Lower(std::string s)
        {
            std::transform(s.begin(), s.end(), s.begin(),
                [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            return s;
        }

        std::string EventsHash(const std::vector<std::vector<std::string>>& events)
        {
            std::ostringstream oss;
            for (size_t p = 0; p < events.size(); ++p) {
                if (p)
                    oss << '|';
                for (size_t s = 0; s < events[p].size(); ++s) {
                    if (s)
                        oss << ',';
                    oss << events[p][s];
                }
            }
            const std::string raw = oss.str();
            uint64_t h = 14695981039346656037ull;
            for (unsigned char c : raw) {
                h ^= c;
                h *= 1099511628211ull;
            }
            std::ostringstream hex;
            hex << std::hex << h;
            return hex.str();
        }

        bool Exec(const char* sql)
        {
            if (!g_db)
                return false;
            char* err = nullptr;
            if (sqlite3_exec(g_db, sql, nullptr, nullptr, &err) != SQLITE_OK) {
                webui_log::error("AniDescriber SQL: {}", err ? err : "unknown");
                sqlite3_free(err);
                return false;
            }
            return true;
        }

        bool OpenDb()
        {
            if (g_db)
                return true;
            auto path = AnimationDB::PluginDataDir() / "anidescriber.sql";
            std::error_code ec;
            std::filesystem::create_directories(path.parent_path(), ec);
            if (sqlite3_open(path.string().c_str(), &g_db) != SQLITE_OK) {
                webui_log::error("AniDescriber: failed to open {}", path.string());
                g_db = nullptr;
                return false;
            }
            return Exec(R"SQL(
CREATE TABLE IF NOT EXISTS animinfo (
  registry TEXT PRIMARY KEY,
  events_hash TEXT NOT NULL,
  payload TEXT NOT NULL
);
)SQL");
        }

        nlohmann::json LoadPayloadLocked(const std::string& registry, const std::string& hash)
        {
            if (!OpenDb())
                return nullptr;
            sqlite3_stmt* stmt = nullptr;
            if (sqlite3_prepare_v2(g_db, "SELECT events_hash,payload FROM animinfo WHERE registry=?", -1, &stmt,
                    nullptr) != SQLITE_OK)
                return nullptr;
            sqlite3_bind_text(stmt, 1, registry.c_str(), -1, SQLITE_TRANSIENT);
            nlohmann::json out = nullptr;
            if (sqlite3_step(stmt) == SQLITE_ROW) {
                const unsigned char* h = sqlite3_column_text(stmt, 0);
                const unsigned char* p = sqlite3_column_text(stmt, 1);
                const std::string got = h ? reinterpret_cast<const char*>(h) : "";
                if (got == hash && p) {
                    try {
                        out = nlohmann::json::parse(reinterpret_cast<const char*>(p));
                    } catch (...) {
                        out = nullptr;
                    }
                }
            }
            sqlite3_finalize(stmt);
            return out;
        }

        void StorePayloadLocked(const std::string& registry, const std::string& hash, const nlohmann::json& payload)
        {
            if (!OpenDb())
                return;
            sqlite3_stmt* stmt = nullptr;
            if (sqlite3_prepare_v2(g_db,
                    "INSERT INTO animinfo(registry,events_hash,payload) VALUES(?,?,?) "
                    "ON CONFLICT(registry) DO UPDATE SET events_hash=excluded.events_hash,payload=excluded.payload",
                    -1, &stmt, nullptr) != SQLITE_OK)
                return;
            const std::string dump = payload.dump();
            sqlite3_bind_text(stmt, 1, registry.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt, 2, hash.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt, 3, dump.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_step(stmt);
            sqlite3_finalize(stmt);
        }

        std::filesystem::path GameDataDir()
        {
            wchar_t buf[MAX_PATH]{};
            GetModuleFileNameW(GetModuleHandleW(nullptr), buf, MAX_PATH);
            return std::filesystem::path(buf).parent_path() / "Data";
        }

        bool LoadResourceBytes(const std::string& rel, std::vector<uint8_t>& out)
        {
            if (rel.empty())
                return false;
            RE::BSResourceNiBinaryStream stream(rel.c_str());
            if (!stream.good())
                return false;
            std::uint32_t size = 0;
            if (stream.stream)
                size = stream.stream->totalSize;
            if (size == 0) {
                stream.seek(1 << 28);
                size = stream.tell();
                if (size == 0)
                    return false;
                stream.seek(-static_cast<std::int32_t>(size));
            }
            if (size == 0 || size > 48u * 1024u * 1024u)
                return false;
            out.resize(size);
            if (!stream.read(out.data(), size)) {
                out.clear();
                return false;
            }
            return true;
        }

        void BuildFileIndex()
        {
            if (g_index_ready)
                return;
            g_index_ready = true;
            const auto root = GameDataDir() / "meshes" / "actors" / "character" / "animations";
            std::error_code ec;
            if (!std::filesystem::is_directory(root, ec))
                return;
            for (auto it = std::filesystem::recursive_directory_iterator(root, ec);
                 it != std::filesystem::recursive_directory_iterator(); ++it) {
                if (ec) {
                    ec.clear();
                    continue;
                }
                if (!it->is_regular_file(ec))
                    continue;
                auto ext = Lower(it->path().extension().string());
                auto stem = it->path().filename().string();
                const auto rel = std::filesystem::relative(it->path(), GameDataDir(), ec);
                if (ec || rel.empty())
                    continue;
                std::string rels = rel.generic_string();
                if (ext == ".hkx")
                    g_file_index[Lower(stem)] = rels;
                if (ext == ".txt") {
                    const auto name = Lower(stem);
                    if (name.rfind("fnis_", 0) != 0 || name.find("list") == std::string::npos)
                        continue;
                    std::ifstream in(it->path());
                    std::string line;
                    while (std::getline(in, line)) {
                        if (line.empty() || line[0] == '\'')
                            continue;
                        std::istringstream ls(line);
                        std::vector<std::string> tok;
                        std::string w;
                        while (ls >> w)
                            tok.push_back(w);
                        if (tok.size() < 2)
                            continue;
                        std::string hkx;
                        std::string ev;
                        for (auto& t : tok) {
                            if (Lower(t).ends_with(".hkx"))
                                hkx = t;
                            else if (t.find('_') != std::string::npos && t[0] != '-' && t.size() > 3)
                                ev = t;
                        }
                        if (hkx.empty() || ev.empty())
                            continue;
                        std::replace(hkx.begin(), hkx.end(), '\\', '/');
                        std::string path = hkx;
                        if (path.find('/') == std::string::npos)
                            path = rel.parent_path().generic_string() + "/" + hkx;
                        else if (path.rfind("meshes/", 0) != 0)
                            path = "meshes/actors/character/animations/" + path;
                        g_file_index[Lower(ev + ".hkx")] = path;
                        auto slash = path.find_last_of('/');
                        g_file_index[Lower(slash == std::string::npos ? path : path.substr(slash + 1))] = path;
                    }
                }
            }
            webui_log::info("AniDescriber: indexed {} animation files", g_file_index.size());
        }

        std::string StripBillyyPrefix(const std::string& event)
        {
            // B_B_Foo_A1_S1 → B_Foo_A1_S1
            if (event.size() > 4 && (event[0] == 'B' || event[0] == 'b') && event[1] == '_' &&
                (event[2] == 'B' || event[2] == 'b') && event[3] == '_')
                return event.substr(0, 1) + event.substr(3);
            return event;
        }

        bool LoadClipBytes(const std::string& event, std::vector<uint8_t>& out)
        {
            if (event.empty())
                return false;
            BuildFileIndex();
            std::vector<std::string> names = {event + ".hkx", StripBillyyPrefix(event) + ".hkx"};
            std::vector<std::string> paths;
            for (const auto& n : names) {
                auto it = g_file_index.find(Lower(n));
                if (it != g_file_index.end())
                    paths.push_back(it->second);
                paths.push_back("meshes/actors/character/animations/" + n);
                paths.push_back("meshes/actors/character/animations/SexLabAP/" + n);
                paths.push_back("meshes/actors/character/animations/SexLab/" + n);
            }
            std::unordered_set<std::string> seen;
            for (const auto& p : paths) {
                if (!seen.insert(Lower(p)).second)
                    continue;
                if (LoadResourceBytes(p, out))
                    return true;
            }
            return false;
        }

        void EnsureSkeletons()
        {
            if (g_skel_tried)
                return;
            g_skel_tried = true;
            std::vector<uint8_t> bytes;
            if (LoadResourceBytes("meshes/actors/character/character assets/skeleton.hkx", bytes))
                g_skel_m_ok = HkxAnim::LoadSkeleton(bytes, g_skel_m);
            bytes.clear();
            if (LoadResourceBytes("meshes/actors/character/character assets/skeleton_female.hkx", bytes))
                g_skel_f_ok = HkxAnim::LoadSkeleton(bytes, g_skel_f);
            if (!g_skel_f_ok && g_skel_m_ok) {
                g_skel_f = g_skel_m;
                g_skel_f_ok = true;
            }
            webui_log::info("AniDescriber: skeletons male={} female={} bones_m={}", g_skel_m_ok, g_skel_f_ok,
                g_skel_m.bone_names.size());
        }

        bool HumanRow(const AnimationDB::AnimRow& row)
        {
            if (row.has_creature || row.male_creatures > 0 || row.female_creatures > 0)
                return false;
            for (int g : row.pos_genders) {
                if (g == 2 || g == 3)
                    return false;
            }
            for (const auto& rk : row.pos_race_keys) {
                if (rk.empty())
                    continue;
                const auto l = Lower(rk);
                if (l != "human" && l != "humans")
                    return false;
            }
            return true;
        }

        float Dist(const HkxAnim::Vec3& a, const HkxAnim::Vec3& b)
        {
            const float dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z;
            return std::sqrt(dx * dx + dy * dy + dz * dz);
        }

        HkxAnim::Vec3 Add(const HkxAnim::Vec3& a, const HkxAnim::Vec3& b)
        {
            return {a.x + b.x, a.y + b.y, a.z + b.z};
        }

        HkxAnim::Vec3 Scale(const HkxAnim::Vec3& a, float s)
        {
            return {a.x * s, a.y * s, a.z * s};
        }

        HkxAnim::Vec3 Rotate(const HkxAnim::Quat& q, const HkxAnim::Vec3& v)
        {
            const HkxAnim::Quat p{v.x, v.y, v.z, 0.f};
            const HkxAnim::Quat i{-q.x, -q.y, -q.z, q.w};
            auto mul = [](const HkxAnim::Quat& a, const HkxAnim::Quat& b) {
                return HkxAnim::Quat{
                    a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
                    a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
                    a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
                    a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
                };
            };
            const auto r = mul(mul(q, p), i);
            return {r.x, r.y, r.z};
        }

        int FindFirst(const HkxAnim::Pose& pose, std::initializer_list<const char*> names)
        {
            for (const char* n : names) {
                int i = HkxAnim::FindBone(pose, n);
                if (i >= 0)
                    return i;
            }
            return -1;
        }

        enum class LM : int
        {
            Pelvis = 0,
            Spine,
            Head,
            Mouth,
            Face,
            Chest,
            HandL,
            HandR,
            BreastL,
            BreastR,
            ButtL,
            ButtR,
            Penis,
            Pussy,
            Anus,
            KneeL,
            KneeR,
            Count
        };

        const char* LmName(LM lm)
        {
            switch (lm) {
            case LM::Pelvis:
                return "pelvis";
            case LM::Spine:
                return "spine";
            case LM::Head:
                return "head";
            case LM::Mouth:
                return "mouth";
            case LM::Face:
                return "face";
            case LM::Chest:
                return "chest";
            case LM::HandL:
                return "left hand";
            case LM::HandR:
                return "right hand";
            case LM::BreastL:
                return "left breast";
            case LM::BreastR:
                return "right breast";
            case LM::ButtL:
                return "left butt";
            case LM::ButtR:
                return "right butt";
            case LM::Penis:
                return "penis";
            case LM::Pussy:
                return "pussy";
            case LM::Anus:
                return "anus";
            default:
                return "body";
            }
        }

        bool IsHand(LM lm)
        {
            return lm == LM::HandL || lm == LM::HandR;
        }
        bool IsBreast(LM lm)
        {
            return lm == LM::BreastL || lm == LM::BreastR;
        }
        bool IsButt(LM lm)
        {
            return lm == LM::ButtL || lm == LM::ButtR;
        }
        bool IsGenital(LM lm)
        {
            return lm == LM::Penis || lm == LM::Pussy || lm == LM::Anus;
        }

        const char* HandWord(LM)
        {
            return "hand";
        }
        const char* BreastWord(LM)
        {
            return "breast";
        }
        const char* ButtWord(LM)
        {
            return "butt";
        }

        struct Marks
        {
            HkxAnim::Vec3 p[static_cast<int>(LM::Count)]{};
            bool has[static_cast<int>(LM::Count)]{};
            HkxAnim::Vec3 forward{};
            HkxAnim::Vec3 up{};
            std::string posture;
        };

        void SetMark(Marks& m, LM lm, const HkxAnim::Vec3& v)
        {
            m.p[static_cast<int>(lm)] = v;
            m.has[static_cast<int>(lm)] = true;
        }

        std::string ClassifyPosture(const Marks& m)
        {
            if (!m.has[static_cast<int>(LM::Pelvis)] || !m.has[static_cast<int>(LM::Head)])
                return "standing";
            const auto& pel = m.p[static_cast<int>(LM::Pelvis)];
            const auto& head = m.p[static_cast<int>(LM::Head)];
            const float vert = head.z - pel.z;
            const float hip = pel.z;
            float knee_z = hip;
            int kn = 0;
            if (m.has[static_cast<int>(LM::KneeL)]) {
                knee_z = m.p[static_cast<int>(LM::KneeL)].z;
                ++kn;
            }
            if (m.has[static_cast<int>(LM::KneeR)]) {
                knee_z += m.p[static_cast<int>(LM::KneeR)].z;
                ++kn;
            }
            if (kn)
                knee_z /= static_cast<float>(kn == 2 ? 2 : 1);
            if (kn == 2)
                knee_z = (m.p[static_cast<int>(LM::KneeL)].z + m.p[static_cast<int>(LM::KneeR)].z) * 0.5f;

            const float body_up = vert > 1.f ? vert / std::max(1.f, Dist(head, pel)) : 0.f;
            if (std::abs(body_up) < 0.4f && hip < 55.f) {
                if (m.forward.z > 0.25f)
                    return "supine";
                if (m.forward.z < -0.25f)
                    return "prone";
                if (head.z < hip + 20.f)
                    return "all-fours";
                return "prone";
            }
            if (hip < 50.f && body_up > 0.45f) {
                if (kn && knee_z < hip - 8.f && knee_z < 30.f)
                    return "kneeling";
                return "sitting";
            }
            if (hip < 70.f && kn && knee_z < 25.f && body_up > 0.4f)
                return "kneeling";
            return "standing";
        }

        Marks Landmarks(const HkxAnim::Pose& pose, int gender)
        {
            Marks m;
            auto bone = [&](std::initializer_list<const char*> names) {
                return FindFirst(pose, names);
            };
            auto pos = [&](int b) { return HkxAnim::BoneWorldPos(pose, b); };

            const int pel = bone({"npc pelvis", "pelvis", "npc pelvis [pelv]"});
            const int spn = bone({"npc spine2", "npc spine1", "spine2", "npc spine"});
            const int head = bone({"npc head", "head", "npc head [head]"});
            const int jaw = bone({"npc jaw", "jaw", "npc head magichead"});
            const int hl = bone({"npc l hand", "l hand", "npc l hand [lhnd]"});
            const int hr = bone({"npc r hand", "r hand", "npc r hand [rhnd]"});
            const int bl = bone({"npc l breast", "l breast", "npc l breast [lbre]"});
            const int br = bone({"npc r breast", "r breast", "npc r breast [rbre]"});
            const int btl = bone({"npc l butt", "l butt", "npc l buttock"});
            const int btr = bone({"npc r butt", "r butt", "npc r buttock"});
            const int penis = bone({"npc genitals06", "npc genitals05", "npc genitals04", "npc genitals01",
                "sos1", "schlong", "npc penis"});
            const int pussy = bone({"npc l pussy", "npc vagina", "vagina", "npc clit", "pussy"});
            const int anus = bone({"npc anus", "anus", "npc anal"});
            const int kl = bone({"npc l calf", "npc l knee", "l calf"});
            const int kr = bone({"npc r calf", "npc r knee", "r calf"});

            if (pel >= 0) {
                SetMark(m, LM::Pelvis, pos(pel));
                const auto& xf = pose.world[static_cast<size_t>(pel)];
                m.forward = Rotate(xf.rotation, {0.f, 1.f, 0.f});
                m.up = Rotate(xf.rotation, {0.f, 0.f, 1.f});
            }
            if (spn >= 0)
                SetMark(m, LM::Spine, pos(spn));
            if (head >= 0) {
                SetMark(m, LM::Head, pos(head));
                SetMark(m, LM::Face, pos(head));
            }
            if (jaw >= 0)
                SetMark(m, LM::Mouth, pos(jaw));
            else if (head >= 0 && pel >= 0) {
                const auto& xf = pose.world[static_cast<size_t>(head)];
                SetMark(m, LM::Mouth, Add(pos(head), Scale(Rotate(xf.rotation, {0.f, 1.f, 0.f}), 4.f)));
            }
            if (hl >= 0)
                SetMark(m, LM::HandL, pos(hl));
            if (hr >= 0)
                SetMark(m, LM::HandR, pos(hr));
            if (bl >= 0)
                SetMark(m, LM::BreastL, pos(bl));
            else if (spn >= 0)
                SetMark(m, LM::BreastL, Add(pos(spn), {-6.f, 4.f, 2.f}));
            if (br >= 0)
                SetMark(m, LM::BreastR, pos(br));
            else if (spn >= 0)
                SetMark(m, LM::BreastR, Add(pos(spn), {6.f, 4.f, 2.f}));
            if (spn >= 0)
                SetMark(m, LM::Chest, pos(spn));
            if (btl >= 0)
                SetMark(m, LM::ButtL, pos(btl));
            else if (pel >= 0)
                SetMark(m, LM::ButtL, Add(m.p[static_cast<int>(LM::Pelvis)], Scale(m.forward, -8.f)));
            if (btr >= 0)
                SetMark(m, LM::ButtR, pos(btr));
            else if (pel >= 0)
                SetMark(m, LM::ButtR, Add(m.p[static_cast<int>(LM::Pelvis)], Scale(m.forward, -8.f)));
            if (penis >= 0)
                SetMark(m, LM::Penis, pos(penis));
            else if ((gender == 0 || gender == 2) && pel >= 0)
                SetMark(m, LM::Penis, Add(m.p[static_cast<int>(LM::Pelvis)], Scale(m.forward, 10.f)));
            if (pussy >= 0)
                SetMark(m, LM::Pussy, pos(pussy));
            else if ((gender == 1 || gender == 3) && pel >= 0)
                SetMark(m, LM::Pussy, Add(m.p[static_cast<int>(LM::Pelvis)], Add(Scale(m.forward, 6.f), {0, 0, -3.f})));
            if (anus >= 0)
                SetMark(m, LM::Anus, pos(anus));
            else if (pel >= 0)
                SetMark(m, LM::Anus, Add(m.p[static_cast<int>(LM::Pelvis)], Scale(m.forward, -6.f)));
            if (kl >= 0)
                SetMark(m, LM::KneeL, pos(kl));
            if (kr >= 0)
                SetMark(m, LM::KneeR, pos(kr));
            m.posture = ClassifyPosture(m);
            return m;
        }

        struct Contact
        {
            int a = 0;
            int b = 0;
            LM la = LM::HandR;
            LM lb = LM::Pussy;
            int depth = 1; // 0 in, 1 on
            int votes = 0;
        };

        int ContactKey(const Contact& c)
        {
            return (c.a << 24) | (c.b << 16) | (static_cast<int>(c.la) << 8) | static_cast<int>(c.lb);
        }

        void AddDistances(const std::vector<Marks>& actors, std::unordered_map<int, Contact>& acc)
        {
            const int n = static_cast<int>(actors.size());
            static const LM lefts[] = {LM::HandL, LM::HandR, LM::Mouth, LM::Penis, LM::Pussy, LM::Anus, LM::Face,
                LM::BreastL, LM::BreastR, LM::ButtL, LM::ButtR, LM::Head};
            static const LM rights[] = {LM::Penis, LM::Pussy, LM::Anus, LM::Mouth, LM::Face, LM::BreastL, LM::BreastR,
                LM::ButtL, LM::ButtR, LM::Head, LM::Chest};
            for (int i = 0; i < n; ++i) {
                for (int j = 0; j < n; ++j) {
                    for (LM la : lefts) {
                        if (!actors[static_cast<size_t>(i)].has[static_cast<int>(la)])
                            continue;
                        for (LM lb : rights) {
                            if (i == j && la == lb)
                                continue;
                            if (!actors[static_cast<size_t>(j)].has[static_cast<int>(lb)])
                                continue;
                            // skip nonsense pairs
                            if (!IsHand(la) && la != LM::Mouth && !IsGenital(la) && la != LM::Face)
                                continue;
                            const float d = Dist(actors[static_cast<size_t>(i)].p[static_cast<int>(la)],
                                actors[static_cast<size_t>(j)].p[static_cast<int>(lb)]);
                            if (d > kOn)
                                continue;
                            Contact c{i, j, la, lb, d <= kIn ? 0 : 1, 1};
                            auto& slot = acc[ContactKey(c)];
                            if (slot.votes == 0)
                                slot = c;
                            else {
                                slot.votes += 1;
                                if (c.depth < slot.depth)
                                    slot.depth = c.depth;
                            }
                        }
                    }
                }
            }
        }

        std::string ActorTok(int i)
        {
            return "{{sl.actors." + std::to_string(i) + "}}";
        }
        std::string Poss(int i)
        {
            return ActorTok(i) + "'s";
        }

        const char* LmNoun(LM lm)
        {
            if (IsHand(lm))
                return HandWord(lm);
            if (IsBreast(lm))
                return BreastWord(lm);
            if (IsButt(lm))
                return ButtWord(lm);
            return LmName(lm);
        }

        int ContactRank(const Contact& c)
        {
            const bool gen = IsGenital(c.la) || IsGenital(c.lb);
            const bool hand = IsHand(c.la) || IsHand(c.lb);
            const bool mouth = c.la == LM::Mouth || c.lb == LM::Mouth;
            if (gen && (hand || mouth || (IsGenital(c.la) && IsGenital(c.lb))))
                return 0;
            if (hand && (IsBreast(c.lb) || IsButt(c.lb) || c.lb == LM::Face || IsGenital(c.lb)))
                return 1;
            if (mouth && (IsBreast(c.lb) || IsGenital(c.lb) || c.lb == LM::Face || c.lb == LM::Head))
                return 2;
            if (c.la == LM::Mouth && (c.lb == LM::Mouth || c.lb == LM::Face || c.lb == LM::Head))
                return 3;
            return 8;
        }

        std::string RelativeClause(const std::vector<Marks>& actors)
        {
            if (actors.size() < 2)
                return {};
            const auto& a = actors[0];
            const auto& b = actors[1];
            if (!a.has[static_cast<int>(LM::Pelvis)] || !b.has[static_cast<int>(LM::Pelvis)])
                return {};
            const auto ap = a.p[static_cast<int>(LM::Pelvis)];
            const auto bp = b.p[static_cast<int>(LM::Pelvis)];
            HkxAnim::Vec3 d{bp.x - ap.x, bp.y - ap.y, bp.z - ap.z};
            const float mag = std::max(1.f, Dist(ap, bp));
            const float fwd = (d.x * a.forward.x + d.y * a.forward.y + d.z * a.forward.z) / mag;
            HkxAnim::Vec3 right{a.forward.y * a.up.z - a.forward.z * a.up.y,
                a.forward.z * a.up.x - a.forward.x * a.up.z, a.forward.x * a.up.y - a.forward.y * a.up.x};
            const float side = (d.x * right.x + d.y * right.y + d.z * right.z) / mag;
            const float up = d.z / mag;

            auto otk = [&](int sit, int over) -> bool {
                const auto& s = actors[static_cast<size_t>(sit)];
                const auto& o = actors[static_cast<size_t>(over)];
                if (s.posture != "sitting" && s.posture != "kneeling")
                    return false;
                if (!s.has[static_cast<int>(LM::KneeL)] && !s.has[static_cast<int>(LM::KneeR)])
                    return false;
                HkxAnim::Vec3 knee = s.has[static_cast<int>(LM::KneeR)] ? s.p[static_cast<int>(LM::KneeR)]
                                                                        : s.p[static_cast<int>(LM::KneeL)];
                if (s.has[static_cast<int>(LM::KneeL)] && s.has[static_cast<int>(LM::KneeR)])
                    knee = Scale(Add(s.p[static_cast<int>(LM::KneeL)], s.p[static_cast<int>(LM::KneeR)]), 0.5f);
                const float dk = Dist(o.p[static_cast<int>(LM::Pelvis)], knee);
                return dk < 40.f && (o.posture == "prone" || o.posture == "supine" || o.posture == "all-fours" ||
                                        o.p[static_cast<int>(LM::Pelvis)].z < s.p[static_cast<int>(LM::Head)].z);
            };
            if (otk(1, 0))
                return ActorTok(0) + " is over " + Poss(1) + " knee";
            if (otk(0, 1))
                return ActorTok(1) + " is over " + Poss(0) + " knee";
            if (up > 0.35f && mag < 40.f)
                return ActorTok(1) + " is astride " + ActorTok(0);
            if (fwd < -0.35f)
                return ActorTok(1) + " is behind " + ActorTok(0);
            if (fwd > 0.35f)
                return ActorTok(1) + " is in front of " + ActorTok(0);
            if (std::abs(side) > 0.4f)
                return ActorTok(1) + " is beside " + ActorTok(0);
            return {};
        }

        std::string WriteSentence(const std::vector<Marks>& actors, const std::vector<Contact>& contacts)
        {
            std::vector<Contact> cs = contacts;
            std::sort(cs.begin(), cs.end(), [](const Contact& a, const Contact& b) {
                const int ra = ContactRank(a), rb = ContactRank(b);
                if (ra != rb)
                    return ra < rb;
                if (a.depth != b.depth)
                    return a.depth < b.depth;
                return a.votes > b.votes;
            });

            std::vector<std::string> clauses;
            std::unordered_set<std::string> used;
            auto add = [&](std::string c) {
                if (c.empty() || used.contains(c) || clauses.size() >= 6)
                    return;
                used.insert(c);
                clauses.push_back(std::move(c));
            };

            for (const auto& c : cs) {
                if (ContactRank(c) > 3)
                    continue;
                const char* prep = c.depth == 0 ? "in" : "on";
                std::string left = Poss(c.a) + " " + LmNoun(c.la);
                std::string right = Poss(c.b) + " " + LmNoun(c.lb);
                if (c.la == LM::Mouth && (c.lb == LM::Mouth || c.lb == LM::Face || c.lb == LM::Head) && c.a != c.b)
                    add(ActorTok(c.a) + " is kissing " + ActorTok(c.b));
                else
                    add(left + " is " + prep + " " + right);
            }

            if (clauses.size() < 6) {
                auto rel = RelativeClause(actors);
                add(rel);
            }
            if (clauses.size() < 6) {
                for (size_t i = 0; i < actors.size(); ++i) {
                    if (actors[i].posture.empty())
                        continue;
                    add(ActorTok(static_cast<int>(i)) + " is " + actors[i].posture);
                }
            }
            if (clauses.empty())
                return {};
            std::ostringstream oss;
            for (size_t i = 0; i < clauses.size(); ++i) {
                if (i)
                    oss << ". ";
                oss << clauses[i];
            }
            return oss.str();
        }

        enum class SampleFail : uint8_t
        {
            Ok = 0,
            NoSkeleton,
            LoadFail,
            HkxSampleFail,
            LandmarkMiss,
        };

        bool SampleActor(const std::string& event, int gender, float t01, Marks& out,
            std::unordered_map<std::string, std::vector<uint8_t>>& clips, SampleFail& fail)
        {
            fail = SampleFail::Ok;
            EnsureSkeletons();
            const bool female = gender == 1 || gender == 3;
            const HkxAnim::Skeleton* sk = female ? (g_skel_f_ok ? &g_skel_f : nullptr)
                                                 : (g_skel_m_ok ? &g_skel_m : nullptr);
            if (!sk && g_skel_m_ok)
                sk = &g_skel_m;
            if (!sk) {
                fail = SampleFail::NoSkeleton;
                return false;
            }
            auto it = clips.find(event);
            if (it == clips.end()) {
                std::vector<uint8_t> bytes;
                if (!LoadClipBytes(event, bytes)) {
                    fail = SampleFail::LoadFail;
                    return false;
                }
                it = clips.emplace(event, std::move(bytes)).first;
            }
            HkxAnim::Pose pose;
            if (!HkxAnim::SampleAnimation(it->second, *sk, t01, pose)) {
                fail = SampleFail::HkxSampleFail;
                return false;
            }
            out = Landmarks(pose, gender);
            if (!(out.has[static_cast<int>(LM::Pelvis)] || out.has[static_cast<int>(LM::Head)])) {
                fail = SampleFail::LandmarkMiss;
                return false;
            }
            return true;
        }

        const char* FailName(SampleFail f)
        {
            switch (f) {
            case SampleFail::NoSkeleton:
                return "no_skeleton";
            case SampleFail::LoadFail:
                return "load_fail";
            case SampleFail::HkxSampleFail:
                return "hkx_sample_fail";
            case SampleFail::LandmarkMiss:
                return "landmark_miss";
            default:
                return "ok";
            }
        }

        bool HasTag(const AnimationDB::AnimRow& row, const char* t)
        {
            const std::string needle = t;
            for (const auto& tag : row.tags) {
                if (tag == needle)
                    return true;
            }
            for (const auto& [_, tags] : row.stage_tags) {
                for (const auto& tag : tags) {
                    if (tag == needle)
                        return true;
                }
            }
            return false;
        }

        nlohmann::json Analyze(const AnimationDB::AnimRow& row)
        {
            nlohmann::json payload = nlohmann::json::object();
            payload["sampled"] = false;
            payload["stages"] = nlohmann::json::object();
            payload["orgasm_expected"] = nlohmann::json::array();
            payload["cum_events"] = nlohmann::json::array();
            const int npos = std::max(0, row.position_count);
            const int nstages = std::max(0, row.stage_count);
            for (int i = 0; i < npos; ++i)
                payload["orgasm_expected"].push_back(0);
            if (!HumanRow(row) || npos <= 0 || nstages <= 0)
                return payload;

            bool events_missing = row.anim_events.empty() ||
                static_cast<int>(row.anim_events.size()) < npos;
            if (!events_missing) {
                for (int p = 0; p < npos; ++p) {
                    if (row.anim_events[static_cast<size_t>(p)].empty()) {
                        events_missing = true;
                        break;
                    }
                }
            }
            if (events_missing) {
                webui_log::info("AniDescriber: {} skipped sample — empty anim_events", row.registry);
                payload["fail_reason"] = "empty_anim_events";
                return payload;
            }

            EnsureSkeletons();
            if (!g_skel_m_ok && !g_skel_f_ok) {
                webui_log::info("AniDescriber: {} skipped sample — no skeletons", row.registry);
                payload["fail_reason"] = "no_skeleton";
                return payload;
            }

            webui_log::info("AniDescriber: {} inferring from HKX", row.registry);

            std::vector<int> orgasm(static_cast<size_t>(npos), 0);
            std::vector<int> genital_touch(static_cast<size_t>(npos), 0);
            std::vector<int> mouth_busy(static_cast<size_t>(npos), 0);
            std::vector<int> kissing(static_cast<size_t>(npos), 0);
            bool any = false;

            struct StagePack
            {
                std::string desc;
                std::vector<Contact> contacts;
                std::vector<Marks> mid;
            };
            std::vector<StagePack> packs(static_cast<size_t>(nstages));
            std::unordered_map<std::string, std::vector<uint8_t>> clips;
            SampleFail first_fail = SampleFail::Ok;
            std::string fail_event;

            for (int s = 1; s <= nstages; ++s) {
                std::unordered_map<int, Contact> acc;
                std::vector<Marks> mid_marks(static_cast<size_t>(npos));
                int ok_actors = 0;
                for (int sm = 0; sm < kSampleN; ++sm) {
                    std::vector<Marks> sample(static_cast<size_t>(npos));
                    int got = 0;
                    for (int p = 0; p < npos; ++p) {
                        std::string ev;
                        if (p < static_cast<int>(row.anim_events.size()) &&
                            s - 1 < static_cast<int>(row.anim_events[static_cast<size_t>(p)].size()))
                            ev = row.anim_events[static_cast<size_t>(p)][static_cast<size_t>(s - 1)];
                        int g = p < static_cast<int>(row.pos_genders.size()) ? row.pos_genders[static_cast<size_t>(p)]
                                                                            : 0;
                        Marks m;
                        SampleFail fail = SampleFail::Ok;
                        if (SampleActor(ev, g, kSampleT[sm], m, clips, fail)) {
                            sample[static_cast<size_t>(p)] = m;
                            ++got;
                        } else if (first_fail == SampleFail::Ok && fail != SampleFail::Ok) {
                            first_fail = fail;
                            fail_event = ev;
                        }
                    }
                    if (got < npos)
                        continue;
                    any = true;
                    AddDistances(sample, acc);
                    if (sm == 1)
                        mid_marks = sample;
                    ok_actors = got;
                }
                if (ok_actors < npos && !any)
                    continue;

                std::vector<Contact> kept;
                for (auto& [_, c] : acc) {
                    if (c.votes >= 2)
                        kept.push_back(c);
                }
                for (const auto& c : kept) {
                    if (IsGenital(c.la) && (IsHand(c.lb) || c.lb == LM::Mouth || IsGenital(c.lb)))
                        genital_touch[static_cast<size_t>(c.a)] = 1;
                    if (IsGenital(c.lb) && (IsHand(c.la) || c.la == LM::Mouth || IsGenital(c.la)))
                        genital_touch[static_cast<size_t>(c.b)] = 1;
                    if (c.la == LM::Mouth && (IsGenital(c.lb) || IsHand(c.lb)))
                        mouth_busy[static_cast<size_t>(c.a)] = 1;
                    if (c.lb == LM::Mouth && (IsGenital(c.la) || IsHand(c.la)))
                        mouth_busy[static_cast<size_t>(c.b)] = 1;
                    if (c.la == LM::Mouth && (c.lb == LM::Mouth || c.lb == LM::Face) && c.a != c.b) {
                        kissing[static_cast<size_t>(c.a)] = 1;
                        kissing[static_cast<size_t>(c.b)] = 1;
                    }
                }
                StagePack pack;
                pack.contacts = kept;
                pack.mid = mid_marks;
                auto authored = row.stage_descriptions.find(s);
                if (authored != row.stage_descriptions.end() && !authored->second.empty())
                    pack.desc.clear();
                else
                    pack.desc = WriteSentence(mid_marks, kept);
                packs[static_cast<size_t>(s - 1)] = std::move(pack);
            }

            if (!any) {
                const char* reason =
                    FailName(first_fail == SampleFail::Ok ? SampleFail::LoadFail : first_fail);
                webui_log::info("AniDescriber: {} sample failed — {} event='{}' bones_m={}", row.registry,
                    reason, fail_event, g_skel_m.bone_names.size());
                payload["fail_reason"] = reason;
                return payload;
            }
            payload["sampled"] = true;

            // Cum: last stage site + nearby donor genitals.
            const int cum_stage = nstages;
            const auto& last = packs[static_cast<size_t>(cum_stage - 1)].mid;
            auto nearest_donor = [&](int site_actor, LM site) -> int {
                if (site_actor < 0 || site_actor >= npos || last.size() != static_cast<size_t>(npos))
                    return -1;
                if (!last[static_cast<size_t>(site_actor)].has[static_cast<int>(site)])
                    return -1;
                const auto sp = last[static_cast<size_t>(site_actor)].p[static_cast<int>(site)];
                int best = -1;
                float bd = kOn + 5.f;
                for (int p = 0; p < npos; ++p) {
                    for (LM g : {LM::Penis, LM::Pussy, LM::Anus}) {
                        if (!last[static_cast<size_t>(p)].has[static_cast<int>(g)])
                            continue;
                        const float d = Dist(last[static_cast<size_t>(p)].p[static_cast<int>(g)], sp);
                        if (d < bd) {
                            bd = d;
                            best = p;
                        }
                    }
                }
                return best;
            };

            LM tag_site = LM::Count;
            int tag_site_actor = 0;
            if (HasTag(row, "facial"))
                tag_site = LM::Face;
            else if (HasTag(row, "cuminmouth"))
                tag_site = LM::Mouth;
            else if (HasTag(row, "chestcum"))
                tag_site = LM::Chest;
            else if (HasTag(row, "creampie"))
                tag_site = LM::Pussy;
            else if (HasTag(row, "analcreampie"))
                tag_site = LM::Anus;

            int donor = -1;
            LM used_site = tag_site;
            int used_actor = tag_site_actor;
            if (tag_site != LM::Count) {
                donor = nearest_donor(tag_site_actor, tag_site);
                if (donor < 0 && npos > 1)
                    donor = nearest_donor(1, tag_site);
            }
            if (donor < 0 && last.size() == static_cast<size_t>(npos)) {
                float best = kOn + 5.f;
                for (int rec = 0; rec < npos; ++rec) {
                    for (LM site : {LM::Face, LM::Mouth, LM::Chest, LM::Pussy, LM::Anus, LM::BreastL, LM::BreastR}) {
                        if (!last[static_cast<size_t>(rec)].has[static_cast<int>(site)])
                            continue;
                        for (int dnr = 0; dnr < npos; ++dnr) {
                            if (dnr == rec)
                                continue;
                            for (LM g : {LM::Penis, LM::Pussy, LM::Anus}) {
                                if (!last[static_cast<size_t>(dnr)].has[static_cast<int>(g)])
                                    continue;
                                const float d = Dist(last[static_cast<size_t>(dnr)].p[static_cast<int>(g)],
                                    last[static_cast<size_t>(rec)].p[static_cast<int>(site)]);
                                if (d < best) {
                                    best = d;
                                    donor = dnr;
                                    used_site = site;
                                    used_actor = rec;
                                }
                            }
                        }
                    }
                }
                if (best > kOn)
                    donor = -1;
            }
            if (donor >= 0 && donor < npos) {
                orgasm[static_cast<size_t>(donor)] = 1;
                nlohmann::json ce = nlohmann::json::object();
                ce["stage"] = cum_stage;
                ce["site_actor"] = used_actor;
                ce["site"] = LmName(used_site == LM::Count ? LM::Face : used_site);
                ce["donor"] = donor;
                payload["cum_events"].push_back(ce);
            }

            for (int i = 0; i < npos; ++i) {
                if (genital_touch[static_cast<size_t>(i)])
                    orgasm[static_cast<size_t>(i)] = 1;
                payload["orgasm_expected"][i] = orgasm[static_cast<size_t>(i)];
            }

            nlohmann::json speaking = nlohmann::json::array();
            for (int i = 0; i < npos; ++i) {
                std::vector<std::string> mods;
                if (i < static_cast<int>(row.pos_speaking_modifiers.size()) &&
                    (i >= static_cast<int>(row.speaking_authored.size()) || !row.speaking_authored[static_cast<size_t>(i)])) {
                    if (mouth_busy[static_cast<size_t>(i)])
                        mods.push_back("_gagged_");
                    if (kissing[static_cast<size_t>(i)])
                        mods.push_back("_kissing_");
                }
                speaking.push_back(mods);
            }
            payload["speaking_extra"] = speaking;

            for (int s = 1; s <= nstages; ++s) {
                nlohmann::json st = nlohmann::json::object();
                st["description"] = packs[static_cast<size_t>(s - 1)].desc;
                nlohmann::json cj = nlohmann::json::array();
                for (const auto& c : packs[static_cast<size_t>(s - 1)].contacts) {
                    cj.push_back({{"a", c.a}, {"b", c.b}, {"la", LmNoun(c.la)}, {"lb", LmNoun(c.lb)},
                        {"in", c.depth == 0}, {"votes", c.votes}});
                }
                st["contacts"] = cj;
                if (!packs[static_cast<size_t>(s - 1)].mid.empty()) {
                    nlohmann::json ps = nlohmann::json::array();
                    for (const auto& m : packs[static_cast<size_t>(s - 1)].mid)
                        ps.push_back(m.posture);
                    st["posture"] = ps;
                    st["relative"] = RelativeClause(packs[static_cast<size_t>(s - 1)].mid);
                }
                payload["stages"][std::to_string(s)] = st;
            }

            if (Lower(row.registry).find("spankdog") != std::string::npos ||
                Lower(row.registry).find("matingp1") != std::string::npos ||
                Lower(row.registry).find("cganal") != std::string::npos) {
                webui_log::info("AniDescriber spike {}: sampled={} stage1='{}' orgasm={}", row.registry,
                    payload["sampled"].get<bool>(),
                    packs.empty() ? "" : packs[0].desc, payload["orgasm_expected"].dump());
            }
            return payload;
        }

        void ApplyFill(const AnimationDB::AnimRow& row, const nlohmann::json& payload)
        {
            if (!payload.is_object() || !payload.value("sampled", false))
                return;
            std::vector<int> orgasm;
            if (payload.contains("orgasm_expected") && payload["orgasm_expected"].is_array()) {
                for (const auto& el : payload["orgasm_expected"]) {
                    if (el.is_number_integer())
                        orgasm.push_back(el.get<int>() ? 1 : 0);
                }
            }
            std::vector<std::string> extra(static_cast<size_t>(std::max(0, row.position_count)));
            if (payload.contains("speaking_extra") && payload["speaking_extra"].is_array()) {
                int i = 0;
                for (const auto& el : payload["speaking_extra"]) {
                    if (i >= static_cast<int>(extra.size()))
                        break;
                    std::ostringstream oss;
                    if (el.is_array()) {
                        bool first = true;
                        for (const auto& m : el) {
                            if (!m.is_string())
                                continue;
                            if (!first)
                                oss << ',';
                            first = false;
                            oss << m.get<std::string>();
                        }
                    }
                    extra[static_cast<size_t>(i++)] = oss.str();
                }
            }
            AnimationDB::ApplyGeneratedFill(row.registry, orgasm, extra);
        }

        nlohmann::json EnsurePayload(const AnimationDB::AnimRow& row)
        {
            const std::string reg = Lower(row.registry);
            const std::string hash = EventsHash(row.anim_events);
            const std::string fail_key = reg + "|" + hash;
            nlohmann::json cached = nullptr;
            {
                std::lock_guard lock(g_mutex);
                if (auto fit = g_fail_cache.find(fail_key); fit != g_fail_cache.end()) {
                    nlohmann::json empty = nlohmann::json::object();
                    empty["sampled"] = false;
                    empty["stages"] = nlohmann::json::object();
                    empty["fail_reason"] = fit->second;
                    return empty;
                }
                cached = LoadPayloadLocked(reg, hash);
            }
            if (cached.is_object() && cached.value("sampled", false)) {
                ApplyFill(row, cached);
                return cached;
            }
            auto payload = Analyze(row);
            if (payload.is_object() && payload.value("sampled", false)) {
                std::lock_guard lock(g_mutex);
                g_fail_cache.erase(fail_key);
                StorePayloadLocked(reg, hash, payload);
            } else {
                std::string reason = "sample_failed";
                if (payload.is_object() && payload.contains("fail_reason") && payload["fail_reason"].is_string())
                    reason = payload["fail_reason"].get<std::string>();
                std::lock_guard lock(g_mutex);
                g_fail_cache[fail_key] = reason;
            }
            ApplyFill(row, payload);
            return payload;
        }
    }

    std::string Describe(const std::string& registry, int stage)
    {
        auto row = AnimationDB::GetByRegistry(registry);
        if (!row)
            return {};
        auto payload = EnsurePayload(*row);
        if (!payload.is_object())
            return {};
        const std::string key = std::to_string(stage);
        if (!payload.contains("stages") || !payload["stages"].contains(key))
            return {};
        const auto& st = payload["stages"][key];
        if (st.contains("description") && st["description"].is_string())
            return st["description"].get<std::string>();
        return {};
    }

    void Ensure(const AnimationDB::AnimRow& row)
    {
        EnsurePayload(row);
    }

    std::string Dump(const std::string& registry)
    {
        auto row = AnimationDB::GetByRegistry(registry);
        if (!row)
            return "{}";
        return EnsurePayload(*row).dump(2);
    }

    void Invalidate(const std::string& registry)
    {
        std::lock_guard lock(g_mutex);
        const auto reg = Lower(registry);
        for (auto it = g_fail_cache.begin(); it != g_fail_cache.end();) {
            if (it->first.rfind(reg + "|", 0) == 0)
                it = g_fail_cache.erase(it);
            else
                ++it;
        }
        if (!OpenDb())
            return;
        sqlite3_stmt* stmt = nullptr;
        if (sqlite3_prepare_v2(g_db, "DELETE FROM animinfo WHERE registry=?", -1, &stmt, nullptr) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, reg.c_str(), -1, SQLITE_TRANSIENT);
            sqlite3_step(stmt);
            sqlite3_finalize(stmt);
        }
    }

    void InvalidateAll()
    {
        std::lock_guard lock(g_mutex);
        g_fail_cache.clear();
        if (!OpenDb())
            return;
        Exec("DELETE FROM animinfo");
        webui_log::info("AniDescriber: cache cleared");
    }

    void Close()
    {
        std::lock_guard lock(g_mutex);
        if (g_db) {
            sqlite3_close(g_db);
            g_db = nullptr;
        }
        g_skel_tried = false;
        g_skel_m_ok = false;
        g_skel_f_ok = false;
        g_index_ready = false;
        g_file_index.clear();
        g_fail_cache.clear();
    }
}
