#include "CorpsePatch.h"
#include "CorpsePatchHashes.h"
#include "WebUI_Log.h"

#include <Windows.h>
#include <bcrypt.h>

#include <atomic>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <optional>
#include <vector>

#pragma comment(lib, "bcrypt.lib")

namespace CorpsePatch
{
    namespace
    {
        std::atomic<bool> g_installed{ false };

        /// Lowercase hex SHA-256 of the file, or nullopt when it cannot be read.
        std::optional<std::string> Sha256File(const std::string& path)
        {
            std::ifstream in(path, std::ios::binary);
            if (!in) {
                return std::nullopt;
            }
            const std::vector<unsigned char> data((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());

            BCRYPT_ALG_HANDLE alg = nullptr;
            if (BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, nullptr, 0) != 0) {
                return std::nullopt;
            }
            unsigned char digest[32]{};
            BCRYPT_HASH_HANDLE hash = nullptr;
            bool ok = BCryptCreateHash(alg, &hash, nullptr, 0, nullptr, 0, 0) == 0;
            ok = ok && BCryptHashData(hash, const_cast<PUCHAR>(data.data()), static_cast<ULONG>(data.size()), 0) == 0;
            ok = ok && BCryptFinishHash(hash, digest, sizeof(digest), 0) == 0;
            if (hash) {
                BCryptDestroyHash(hash);
            }
            BCryptCloseAlgorithmProvider(alg, 0);
            if (!ok) {
                return std::nullopt;
            }
            std::string hex;
            hex.reserve(64);
            for (const unsigned char b : digest) {
                char buf[3];
                std::snprintf(buf, sizeof(buf), "%02x", b);
                hex += buf;
            }
            return hex;
        }
    }

    std::string Recheck(bool pplus)
    {
        if (pplus) {
            g_installed = true;
            return {};
        }
        for (const auto& h : kPexHashes) {
            const std::string file(h.file);
            const auto got = Sha256File("Data/Scripts/" + file);
            if (!got || *got != h.sha256) {
                webui_log::warn("CorpsePatch: {} {} (want {})", file, got ? "sha256 " + *got : "missing", h.sha256);
                g_installed = false;
                return file;
            }
        }
        webui_log::info("CorpsePatch: SexLab 1.66 corpse patch installed");
        g_installed = true;
        return {};
    }

    bool IsInstalled() { return g_installed; }
}
