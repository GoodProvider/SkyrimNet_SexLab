#pragma once

#include <filesystem>
#include <string>
#include <unordered_map>
#include <vector>

/// File helpers shared by the AnimDB registry loaders (SlalLoader, SlsbLoader): the MO2 VFS Data folder, source
/// stamps, and the FNIS list index (stage event → hkx). No SexLab code. See docs/developers/anim-engine.md §2.
namespace AnimSources
{
    namespace fs = std::filesystem;

    std::string Lower(std::string s);
    std::string Trim(const std::string& s);

    /// <exe dir>/Data (the MO2 VFS view).
    fs::path GameDataDir();
    /// "mtime:size" of a file (change detection for skip-unchanged).
    std::string Stamp(const fs::path& p);
    bool ReadText(const fs::path& p, std::string& out);
    /// *.json directly in dir, sorted by lowercase filename.
    std::vector<fs::path> JsonFilesIn(const fs::path& dir);

    struct FnisEntry
    {
        std::string kind;
        std::string hkx; // Data-relative, forward slashes
        std::vector<std::string> objects;
        std::vector<std::string> animvars;
        bool acyclic = false;
        bool hkx_loose = false;
    };

    /// lowercase event → entry. If the same event appears in several lists, the first wins.
    struct FnisIndex
    {
        std::unordered_map<std::string, FnisEntry> events;
        std::vector<fs::path> lists;
        int lines = 0;
        int dups = 0;

        const FnisEntry* Find(const std::string& event) const;
    };

    /// Data/meshes/actors/<race>[/<sub>]/animations/<pack>/FNIS_*_List.txt, sorted.
    std::vector<fs::path> FindFnisLists(const fs::path& data_dir);
    FnisIndex LoadFnisIndex(const fs::path& data_dir, const std::vector<fs::path>& lists);
}
