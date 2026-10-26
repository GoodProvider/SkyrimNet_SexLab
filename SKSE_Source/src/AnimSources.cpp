#include "AnimSources.h"

#include <Windows.h>

#include <algorithm>
#include <cctype>
#include <fstream>
#include <sstream>
#include <unordered_set>

namespace AnimSources
{
    namespace
    {
        bool IsFnisAnimKind(const std::string& k)
        {
            static const std::unordered_set<std::string> kinds = { "b", "s", "+", "o", "so", "fu", "fuo", "ofa", "pa",
                "km", "ch", "sa", "se", "^" };
            return kinds.contains(Lower(k));
        }

        void SplitWs(const std::string& line, std::vector<std::string>& tok)
        {
            tok.clear();
            std::istringstream ls(line);
            std::string w;
            while (ls >> w)
                tok.push_back(w);
        }

        /// One FNIS_*_List.txt: `kind [-opt,opt] event file.hkx [AnimObjects...]`. ' lines are comments.
        void ParseFnisList(const fs::path& file, const fs::path& data_dir, FnisIndex& index)
        {
            std::ifstream in(file);
            if (!in)
                return;
            std::error_code ec;
            const auto rel_dir = fs::relative(file.parent_path(), data_dir, ec);
            const std::string rel_dir_s = ec ? std::string() : rel_dir.generic_string();
            std::string line;
            std::vector<std::string> tok;
            while (std::getline(in, line)) {
                if (!line.empty() && line.back() == '\r')
                    line.pop_back();
                const auto t = Trim(line);
                if (t.empty() || t[0] == '\'')
                    continue;
                SplitWs(t, tok);
                if (tok.size() < 3 || !IsFnisAnimKind(tok[0]))
                    continue;
                std::size_t i = 1;
                FnisEntry e;
                e.kind = tok[0];
                if (!tok[i].empty() && tok[i][0] == '-') {
                    std::stringstream os(tok[i].substr(1));
                    std::string opt;
                    while (std::getline(os, opt, ',')) {
                        if (opt.size() > 2 && (opt[0] == 'A' || opt[0] == 'a') && (opt[1] == 'V' || opt[1] == 'v'))
                            e.animvars.push_back(opt.substr(2));
                        else if (opt == "a")
                            e.acyclic = true;
                    }
                    ++i;
                }
                if (i + 1 >= tok.size())
                    continue;
                const std::string ev = tok[i];
                std::string hkx = tok[i + 1];
                if (!Lower(hkx).ends_with(".hkx"))
                    continue;
                std::replace(hkx.begin(), hkx.end(), '\\', '/');
                e.hkx = rel_dir_s.empty() ? hkx : rel_dir_s + "/" + hkx;
                for (std::size_t k = i + 2; k < tok.size(); ++k)
                    e.objects.push_back(tok[k]);
                e.hkx_loose = fs::exists(data_dir / e.hkx, ec);
                ++index.lines;
                auto [it, inserted] = index.events.try_emplace(Lower(ev), std::move(e));
                if (!inserted)
                    ++index.dups; // same event in several lists (e.g. canine/dog/wolf copies): first wins
            }
        }

        void ScanForFnisLists(const fs::path& dir, int depth, std::vector<fs::path>& out)
        {
            std::error_code ec;
            for (const auto& ent : fs::directory_iterator(dir, ec)) {
                if (!ent.is_directory(ec))
                    continue;
                const auto name = Lower(ent.path().filename().string());
                if (name == "animations") {
                    for (const auto& pack : fs::directory_iterator(ent.path(), ec)) {
                        if (!pack.is_directory(ec))
                            continue;
                        for (const auto& f : fs::directory_iterator(pack.path(), ec)) {
                            if (!f.is_regular_file(ec))
                                continue;
                            const auto fname = Lower(f.path().filename().string());
                            if (fname.starts_with("fnis_") && fname.ends_with("_list.txt"))
                                out.push_back(f.path());
                        }
                    }
                } else if (depth < 3) {
                    ScanForFnisLists(ent.path(), depth + 1, out);
                }
            }
        }
    }

    std::string Lower(std::string s)
    {
        std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        return s;
    }

    std::string Trim(const std::string& s)
    {
        std::size_t b = 0;
        std::size_t e = s.size();
        while (b < e && std::isspace(static_cast<unsigned char>(s[b])))
            ++b;
        while (e > b && std::isspace(static_cast<unsigned char>(s[e - 1])))
            --e;
        return s.substr(b, e - b);
    }

    fs::path GameDataDir()
    {
        wchar_t buf[MAX_PATH]{};
        GetModuleFileNameW(GetModuleHandleW(nullptr), buf, MAX_PATH);
        return fs::path(buf).parent_path() / "Data";
    }

    std::string Stamp(const fs::path& p)
    {
        std::error_code ec;
        const auto t = fs::last_write_time(p, ec);
        const auto n = ec ? 0 : t.time_since_epoch().count();
        const auto sz = fs::file_size(p, ec);
        return std::to_string(n) + ":" + std::to_string(ec ? 0 : sz);
    }

    bool ReadText(const fs::path& p, std::string& out)
    {
        std::ifstream in(p, std::ios::binary);
        if (!in)
            return false;
        std::ostringstream ss;
        ss << in.rdbuf();
        out = ss.str();
        return true;
    }

    std::vector<fs::path> JsonFilesIn(const fs::path& dir)
    {
        std::vector<fs::path> out;
        std::error_code ec;
        if (!fs::is_directory(dir, ec))
            return out;
        for (const auto& ent : fs::directory_iterator(dir, ec)) {
            if (ent.is_regular_file(ec) && Lower(ent.path().extension().string()) == ".json")
                out.push_back(ent.path());
        }
        std::sort(out.begin(), out.end(),
            [](const fs::path& a, const fs::path& b) { return Lower(a.filename().string()) < Lower(b.filename().string()); });
        return out;
    }

    const FnisEntry* FnisIndex::Find(const std::string& event) const
    {
        auto it = events.find(Lower(event));
        return it == events.end() ? nullptr : &it->second;
    }

    std::vector<fs::path> FindFnisLists(const fs::path& data_dir)
    {
        std::vector<fs::path> lists;
        std::error_code ec;
        if (fs::is_directory(data_dir / "meshes" / "actors", ec))
            ScanForFnisLists(data_dir / "meshes" / "actors", 1, lists);
        std::sort(lists.begin(), lists.end());
        return lists;
    }

    FnisIndex LoadFnisIndex(const fs::path& data_dir, const std::vector<fs::path>& lists)
    {
        FnisIndex index;
        index.lists = lists;
        for (const auto& l : lists)
            ParseFnisList(l, data_dir, index);
        return index;
    }
}
