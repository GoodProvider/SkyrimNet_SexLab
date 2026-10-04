#pragma once
#include <cstdint>
#include <string>

// Local stand-in for SkyrimNet's PublicAPIDiaryQuery.h, which beta26 rc4 includes from PublicAPI.h but does not
// ship (missing from both the main and devkit zips). This plugin never queries diaries; the types only have to
// compile. Delete this file once upstream ships the real header (include/ precedes the devkit CppAPI path).

enum class DiaryOrder : uint32_t {
    IdAsc = 0,
    IdDesc,
};

struct DiaryQuery {
    int maxCount = 50;
    int minId = 0;
    DiaryOrder orderBy = DiaryOrder::IdDesc;
};

inline std::string DiaryQueryToJSON(const DiaryQuery& q) {
    return "{\"maxCount\":" + std::to_string(q.maxCount) + ",\"minId\":" + std::to_string(q.minId) +
           ",\"orderBy\":\"" + (q.orderBy == DiaryOrder::IdAsc ? "IdAsc" : "IdDesc") + "\"}";
}
