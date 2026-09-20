#include "HkxAnim.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <span>
#include <unordered_map>

namespace HkxAnim
{
    namespace
    {
        constexpr uint32_t kMagic0 = 0x57E0E057u;
        constexpr uint32_t kMagic1 = 0x10C0C010u;

        struct Section
        {
            char tag[20]{};
            int32_t abs_start = 0;
            int32_t local_fixups = 0;
            int32_t global_fixups = 0;
            int32_t virtual_fixups = 0;
            int32_t exports = 0;
            int32_t imports = 0;
            int32_t end = 0;
        };

        struct HkArray
        {
            void* ptr = nullptr;
            int32_t size = 0;
            int32_t cap = 0;
        };

        float ReadF32(const uint8_t* p)
        {
            float v;
            std::memcpy(&v, p, 4);
            return v;
        }

        int32_t ReadI32(const uint8_t* p)
        {
            int32_t v;
            std::memcpy(&v, p, 4);
            return v;
        }

        uint32_t ReadU32(const uint8_t* p)
        {
            uint32_t v;
            std::memcpy(&v, p, 4);
            return v;
        }

        std::string ReadCString(const char* s)
        {
            if (!s)
                return {};
            return std::string(s);
        }

        std::string BoneKey(std::string n)
        {
            auto br = n.find('[');
            if (br != std::string::npos)
                n = n.substr(0, br);
            while (!n.empty() && n.back() == ' ')
                n.pop_back();
            std::transform(n.begin(), n.end(), n.begin(),
                [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            return n;
        }

        Vec3 Add(const Vec3& a, const Vec3& b)
        {
            return {a.x + b.x, a.y + b.y, a.z + b.z};
        }

        Vec3 Mul(const Vec3& a, const Vec3& b)
        {
            return {a.x * b.x, a.y * b.y, a.z * b.z};
        }

        Vec3 Scale(const Vec3& a, float s)
        {
            return {a.x * s, a.y * s, a.z * s};
        }

        Quat MulQ(const Quat& a, const Quat& b)
        {
            return {
                a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
                a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
                a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
                a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
            };
        }

        Vec3 Rotate(const Quat& q, const Vec3& v)
        {
            const Quat p{v.x, v.y, v.z, 0.f};
            const Quat i{-q.x, -q.y, -q.z, q.w};
            const Quat r = MulQ(MulQ(q, p), i);
            return {r.x, r.y, r.z};
        }

        Transform Compose(const Transform& a, const Transform& b)
        {
            Transform o;
            o.rotation = MulQ(a.rotation, b.rotation);
            o.scale = Mul(a.scale, b.scale);
            o.translation = Add(a.translation, Rotate(a.rotation, Mul(a.scale, b.translation)));
            return o;
        }

        Transform ReadQs(const uint8_t* p)
        {
            Transform t;
            t.translation = {ReadF32(p), ReadF32(p + 4), ReadF32(p + 8)};
            t.rotation = {ReadF32(p + 16), ReadF32(p + 20), ReadF32(p + 24), ReadF32(p + 28)};
            t.scale = {ReadF32(p + 32), ReadF32(p + 36), ReadF32(p + 40)};
            return t;
        }

        bool ParsePackfile(const std::vector<uint8_t>& bytes, std::vector<uint8_t>& data,
            std::unordered_map<uint32_t, std::string>& objects)
        {
            if (bytes.size() < 0x40)
                return false;
            if (ReadU32(bytes.data()) != kMagic0 || ReadU32(bytes.data() + 4) != kMagic1)
                return false;
            const int32_t version = ReadI32(bytes.data() + 12);
            const uint8_t ptr_size = bytes[16];
            if (ptr_size != 8)
                return false;
            const int32_t section_count = ReadI32(bytes.data() + 20);
            if (section_count < 1 || section_count > 16)
                return false;
            size_t off = 0x40;
            // contentsVersion string + padding varies; Skyrim SE header is 0x40 then sections.
            // Some files store extra 16 bytes. Detect section tag "__classnames__".
            auto try_sections_at = [&](size_t start) -> bool {
                if (start + static_cast<size_t>(section_count) * 0x30 > bytes.size())
                    return false;
                const char* tag = reinterpret_cast<const char*>(bytes.data() + start);
                return std::memcmp(tag, "__classnames__", 14) == 0 || std::memcmp(tag, "__types__", 9) == 0 ||
                       std::memcmp(tag, "__data__", 8) == 0;
            };
            if (!try_sections_at(off)) {
                off = 0x50;
                if (!try_sections_at(off))
                    off = 0x40;
            }

            std::vector<Section> sections(static_cast<size_t>(section_count));
            for (int i = 0; i < section_count; ++i) {
                const uint8_t* p = bytes.data() + off + static_cast<size_t>(i) * 0x30;
                std::memcpy(sections[static_cast<size_t>(i)].tag, p, 19);
                sections[static_cast<size_t>(i)].abs_start = ReadI32(p + 20);
                sections[static_cast<size_t>(i)].local_fixups = ReadI32(p + 24);
                sections[static_cast<size_t>(i)].global_fixups = ReadI32(p + 28);
                sections[static_cast<size_t>(i)].virtual_fixups = ReadI32(p + 32);
                sections[static_cast<size_t>(i)].exports = ReadI32(p + 36);
                sections[static_cast<size_t>(i)].imports = ReadI32(p + 40);
                sections[static_cast<size_t>(i)].end = ReadI32(p + 44);
            }

            const Section* classnames = nullptr;
            const Section* datasec = nullptr;
            for (const auto& s : sections) {
                if (std::strncmp(s.tag, "__classnames__", 14) == 0)
                    classnames = &s;
                if (std::strncmp(s.tag, "__data__", 8) == 0)
                    datasec = &s;
            }
            if (!classnames || !datasec)
                return false;
            if (datasec->end < datasec->virtual_fixups)
                return false;

            const size_t data_sz = static_cast<size_t>(datasec->end);
            if (static_cast<size_t>(datasec->abs_start) + data_sz > bytes.size())
                return false;
            data.assign(bytes.begin() + datasec->abs_start, bytes.begin() + datasec->abs_start + data_sz);

            auto patch_ptr = [&](int32_t src, int32_t dst) {
                if (src < 0 || static_cast<size_t>(src) + 8 > data.size())
                    return;
                if (dst < 0 || static_cast<size_t>(dst) >= data.size())
                    return;
                uint64_t addr = reinterpret_cast<uint64_t>(data.data() + dst);
                std::memcpy(data.data() + src, &addr, 8);
            };

            for (int32_t p = datasec->local_fixups; p + 8 <= datasec->global_fixups; p += 8) {
                const int32_t src = ReadI32(data.data() + p);
                const int32_t dst = ReadI32(data.data() + p + 4);
                patch_ptr(src, dst);
            }
            for (int32_t p = datasec->global_fixups; p + 12 <= datasec->virtual_fixups; p += 12) {
                const int32_t src = ReadI32(data.data() + p);
                const int32_t dst = ReadI32(data.data() + p + 8);
                patch_ptr(src, dst);
            }

            std::unordered_map<int32_t, std::string> cn;
            const uint8_t* cnbase = bytes.data() + classnames->abs_start;
            const int32_t cn_end = classnames->end;
            int32_t cp = 0;
            while (cp + 5 < cn_end) {
                cp += 4;
                if (cnbase[cp] != 0x09) {
                    ++cp;
                    continue;
                }
                ++cp;
                const char* name = reinterpret_cast<const char*>(cnbase + cp);
                cn[cp] = name;
                cp += static_cast<int32_t>(std::strlen(name)) + 1;
            }

            for (int32_t p = datasec->virtual_fixups; p + 12 <= datasec->exports; p += 12) {
                const int32_t src = ReadI32(data.data() + p);
                const int32_t name_off = ReadI32(data.data() + p + 8);
                auto it = cn.find(name_off);
                if (it != cn.end() && src >= 0)
                    objects[static_cast<uint32_t>(src)] = it->second;
            }
            (void)version;
            return !objects.empty();
        }

        template <class T>
        std::span<T> Arr(const uint8_t* obj, size_t field)
        {
            const auto* a = reinterpret_cast<const HkArray*>(obj + field);
            if (!a->ptr || a->size <= 0)
                return {};
            return {reinterpret_cast<T*>(a->ptr), static_cast<size_t>(a->size)};
        }

        const char* StrPtr(const uint8_t* obj, size_t field)
        {
            const char* s = nullptr;
            std::memcpy(&s, obj + field, 8);
            return s;
        }

        bool ParseSkeleton(const std::vector<uint8_t>& data,
            const std::unordered_map<uint32_t, std::string>& objects, Skeleton& out)
        {
            struct Candidate
            {
                uint32_t off = 0;
                size_t n = 0;
                int npc_bones = 0;
                int ragdoll_bones = 0;
                bool has_npc_pelvis = false;
            };
            std::vector<Candidate> cands;
            struct BoneRec
            {
                const char* name;
                uint8_t pad[8];
            };
            struct QsRec
            {
                uint8_t b[48];
            };

            for (const auto& [off, cls] : objects) {
                if (cls != "hkaSkeleton")
                    continue;
                if (static_cast<size_t>(off) + 0x50 > data.size())
                    continue;
                const uint8_t* o = data.data() + off;
                auto parents = Arr<int16_t>(o, 0x18);
                auto bones = Arr<BoneRec>(o, 0x28);
                const size_t n = parents.size();
                if (n == 0)
                    continue;
                Candidate c;
                c.off = off;
                c.n = n;
                for (size_t i = 0; i < n && i < bones.size(); ++i) {
                    const auto name = ReadCString(bones[i].name);
                    const auto key = BoneKey(name);
                    if (key.rfind("ragdoll_", 0) == 0 || key.find("ragdoll_") != std::string::npos)
                        ++c.ragdoll_bones;
                    else if (key.rfind("npc ", 0) == 0 || key.rfind("npc_", 0) == 0) {
                        ++c.npc_bones;
                        if (key == "npc pelvis")
                            c.has_npc_pelvis = true;
                    }
                }
                cands.push_back(c);
            }
            if (cands.empty())
                return false;

            // Prefer NPC animation skeleton (XPMSE also embeds an 18-bone Ragdoll_* set).
            auto score = [](const Candidate& c) -> int64_t {
                if (c.ragdoll_bones > 0 && c.npc_bones == 0)
                    return static_cast<int64_t>(c.n); // last resort only
                int64_t s = 1'000'000'000LL;
                if (c.has_npc_pelvis)
                    s += 100'000'000LL;
                s += static_cast<int64_t>(c.npc_bones) * 10'000LL;
                s += static_cast<int64_t>(c.n);
                s -= static_cast<int64_t>(c.ragdoll_bones) * 100'000LL;
                return s;
            };
            const Candidate* best = &cands[0];
            for (size_t i = 1; i < cands.size(); ++i) {
                if (score(cands[i]) > score(*best))
                    best = &cands[i];
            }

            const uint8_t* o = data.data() + best->off;
            auto parents = Arr<int16_t>(o, 0x18);
            auto bones = Arr<BoneRec>(o, 0x28);
            auto pose = Arr<QsRec>(o, 0x38);
            const size_t n = parents.size();
            out.parents.assign(parents.begin(), parents.end());
            out.bone_names.resize(n);
            out.bind_local.resize(n);
            for (size_t i = 0; i < n; ++i) {
                if (i < bones.size())
                    out.bone_names[i] = ReadCString(bones[i].name);
                if (i < pose.size())
                    out.bind_local[i] = ReadQs(pose[i].b);
                else
                    out.bind_local[i] = {};
            }
            return true;
        }

        struct SplineAnim
        {
            int32_t type = 0;
            float duration = 1.f;
            int32_t ntracks = 0;
            int32_t nframes = 0;
            int32_t nblocks = 0;
            int32_t max_frames = 256;
            float block_duration = 1.f;
            std::vector<uint32_t> block_offsets;
            std::vector<uint8_t> blob;
            std::vector<int16_t> track_to_bone;
            std::vector<Transform> interleaved;
        };

        bool ParseBindingAndAnim(const std::vector<uint8_t>& data,
            const std::unordered_map<uint32_t, std::string>& objects, SplineAnim& out)
        {
            const uint8_t* anim_obj = nullptr;
            for (const auto& [off, cls] : objects) {
                if (cls == "hkaAnimationBinding") {
                    if (static_cast<size_t>(off) + 0x40 > data.size())
                        continue;
                    const uint8_t* o = data.data() + off;
                    auto map = Arr<int16_t>(o, 0x20);
                    out.track_to_bone.assign(map.begin(), map.end());
                    const uint8_t* ap = nullptr;
                    std::memcpy(&ap, o + 0x18, 8);
                    if (ap && ap >= data.data() && ap < data.data() + data.size())
                        anim_obj = ap;
                }
            }
            if (!anim_obj) {
                for (const auto& [off, cls] : objects) {
                    if (cls == "hkaSplineCompressedAnimation" || cls == "hkaInterleavedUncompressedAnimation") {
                        anim_obj = data.data() + off;
                        break;
                    }
                }
            }
            if (!anim_obj)
                return false;

            out.type = ReadI32(anim_obj + 0x10);
            out.duration = ReadF32(anim_obj + 0x14);
            out.ntracks = ReadI32(anim_obj + 0x18);
            if (out.ntracks <= 0 || out.ntracks > 512)
                return false;

            if (out.type == 1) {
                // interleaved
                struct QsRec
                {
                    uint8_t b[48];
                };
                auto xf = Arr<QsRec>(anim_obj, 0x38);
                out.interleaved.resize(xf.size());
                for (size_t i = 0; i < xf.size(); ++i)
                    out.interleaved[i] = ReadQs(xf[i].b);
                if (out.ntracks > 0)
                    out.nframes = static_cast<int32_t>(xf.size() / static_cast<size_t>(out.ntracks));
                return out.nframes > 0;
            }

            // spline (type 3) or try spline layout anyway
            out.nframes = ReadI32(anim_obj + 0x38);
            out.nblocks = ReadI32(anim_obj + 0x3C);
            out.max_frames = ReadI32(anim_obj + 0x40);
            out.block_duration = ReadF32(anim_obj + 0x48);
            auto offs = Arr<uint32_t>(anim_obj, 0x58);
            out.block_offsets.assign(offs.begin(), offs.end());
            auto blob = Arr<uint8_t>(anim_obj, 0x98);
            out.blob.assign(blob.begin(), blob.end());
            if (out.duration <= 0.f)
                out.duration = 1.f;
            if (out.block_duration <= 0.f && out.nblocks > 0)
                out.block_duration = out.duration / static_cast<float>(out.nblocks);
            return !out.blob.empty() && out.ntracks > 0;
        }

        int Align(int p, int a)
        {
            const int m = p % a;
            return m ? p + (a - m) : p;
        }

        enum class Sub : int
        {
            Identity = 0,
            Static = 1,
            Dynamic = 2
        };

        Sub SubType(uint8_t types, int shift)
        {
            return static_cast<Sub>((types >> shift) & 3);
        }

        bool ReadSplineVector(const uint8_t* blob, int& p, int end, uint8_t types, int type_shift,
            uint8_t quant, float defv, float frame, float& ox, float& oy, float& oz)
        {
            const Sub sx = SubType(types, type_shift);
            const Sub sy = SubType(types, type_shift + 2);
            const Sub sz = SubType(types, type_shift + 4);
            const bool dyn = sx == Sub::Dynamic || sy == Sub::Dynamic || sz == Sub::Dynamic;
            auto rd = [&](float& dst, Sub st) -> bool {
                if (st == Sub::Identity) {
                    dst = defv;
                    return true;
                }
                if (st == Sub::Static) {
                    if (p + 4 > end)
                        return false;
                    dst = ReadF32(blob + p);
                    p += 4;
                    return true;
                }
                return false;
            };
            if (!dyn) {
                if (!rd(ox, sx) || !rd(oy, sy) || !rd(oz, sz))
                    return false;
                return true;
            }
            if (p + 3 > end)
                return false;
            const int nitems = blob[p];
            p += 2;
            const int degree = blob[p++];
            // Degree > 4 exceeds local N[] and is not a valid Havok spline track.
            if (degree < 0 || degree > 4)
                return false;
            const int nknots = nitems + degree + 2;
            if (nknots <= 0 || p + nknots > end)
                return false;
            std::vector<float> knots(static_cast<size_t>(nknots));
            for (int i = 0; i < nknots; ++i)
                knots[static_cast<size_t>(i)] = static_cast<float>(blob[p++]);
            p = Align(p, 4);

            float minv[3]{0, 0, 0}, maxv[3]{0, 0, 0};
            float stat[3]{defv, defv, defv};
            Sub ss[3]{sx, sy, sz};
            for (int c = 0; c < 3; ++c) {
                if (ss[c] == Sub::Dynamic) {
                    if (p + 8 > end)
                        return false;
                    minv[c] = ReadF32(blob + p);
                    maxv[c] = ReadF32(blob + p + 4);
                    p += 8;
                } else if (ss[c] == Sub::Static) {
                    if (p + 4 > end)
                        return false;
                    stat[c] = ReadF32(blob + p);
                    p += 4;
                }
            }

            const int npts = nitems + 1;
            // B-spline eval clamps frame to knots[degree]..knots[npts]; require ordered bounds
            // so MSVC Debug std::clamp never asserts (lo > hi aborts the process).
            if (npts > 1) {
                if (static_cast<size_t>(degree) >= knots.size() ||
                    static_cast<size_t>(npts) >= knots.size())
                    return false;
                const float knot_lo = knots[static_cast<size_t>(degree)];
                const float knot_hi = knots[static_cast<size_t>(npts)];
                if (!(knot_lo <= knot_hi))
                    return false;
            }
            const bool q8 = (quant & 1) == 0;
            std::vector<float> pts[3];
            for (int c = 0; c < 3; ++c)
                pts[c].assign(static_cast<size_t>(npts), stat[c]);
            for (int t = 0; t < npts; ++t) {
                for (int c = 0; c < 3; ++c) {
                    if (ss[c] != Sub::Dynamic)
                        continue;
                    if (q8) {
                        if (p >= end)
                            return false;
                        const float u = blob[p++] / 255.f;
                        pts[c][static_cast<size_t>(t)] = minv[c] + (maxv[c] - minv[c]) * u;
                    } else {
                        if (p + 2 > end)
                            return false;
                        uint16_t u16 = 0;
                        std::memcpy(&u16, blob + p, 2);
                        p += 2;
                        const float u = u16 / 65535.f;
                        pts[c][static_cast<size_t>(t)] = minv[c] + (maxv[c] - minv[c]) * u;
                    }
                }
            }
            p = Align(p, 4);

            auto eval = [&](int c) -> float {
                if (ss[c] != Sub::Dynamic)
                    return stat[c];
                const int n = npts;
                if (n <= 1)
                    return pts[c][0];
                int span = degree;
                const float lo = knots[static_cast<size_t>(degree)];
                const float hi = knots[static_cast<size_t>(n)];
                // Manual clamp: lo <= hi already validated above (avoid std::clamp assert).
                float v = frame;
                if (v < lo)
                    v = lo;
                else if (v > hi)
                    v = hi;
                while (span < n - 1 && v >= knots[static_cast<size_t>(span + 1)])
                    ++span;
                float N[6]{1, 0, 0, 0, 0, 0};
                for (int i = 1; i <= degree && i < 5; ++i) {
                    for (int j = i - 1; j >= 0; --j) {
                        const float den =
                            knots[static_cast<size_t>(span + i - j)] - knots[static_cast<size_t>(span - j)];
                        const float A = den != 0.f ? (v - knots[static_cast<size_t>(span - j)]) / den : 0.f;
                        const float tmp = N[j] * A;
                        N[j + 1] += N[j] - tmp;
                        N[j] = tmp;
                    }
                }
                float r = 0.f;
                for (int i = 0; i <= degree && i < 5; ++i) {
                    const int idx = span - i;
                    if (idx >= 0 && idx < n)
                        r += pts[c][static_cast<size_t>(idx)] * N[i];
                }
                return r;
            };
            ox = eval(0);
            oy = eval(1);
            oz = eval(2);
            return true;
        }

        Quat ReadPackedQuat(const uint8_t* blob, int& p, int end, int qtype)
        {
            Quat q{0, 0, 0, 1};
            if (qtype == 3) {
                if (p + 16 > end)
                    return q;
                q = {ReadF32(blob + p), ReadF32(blob + p + 4), ReadF32(blob + p + 8), ReadF32(blob + p + 12)};
                p += 16;
                return q;
            }
            if (qtype == 0) {
                if (p + 4 > end)
                    return q;
                // 32-bit polar (approximate)
                const uint32_t c = ReadU32(blob + p);
                p += 4;
                const float r = 1.f - std::pow(static_cast<float>((c >> 18) & 1023) / 1023.f, 2.f);
                q.w = r;
                q.x = ((c & 0x3F) / 63.f) * 2.f - 1.f;
                q.y = (((c >> 6) & 0x3F) / 63.f) * 2.f - 1.f;
                q.z = (((c >> 12) & 0x3F) / 63.f) * 2.f - 1.f;
                return q;
            }
            if (qtype == 2) {
                if (p + 6 > end)
                    return q;
                int16_t a, b, c;
                std::memcpy(&a, blob + p, 2);
                std::memcpy(&b, blob + p + 2, 2);
                std::memcpy(&c, blob + p + 4, 2);
                p += 6;
                constexpr float frac = 0.000043161f;
                q.x = (a & 0x7FFF) * frac;
                q.y = (b & 0x7FFF) * frac;
                q.z = (c & 0x7FFF) * frac;
                q.w = std::sqrt(std::max(0.f, 1.f - q.x * q.x - q.y * q.y - q.z * q.z));
                return q;
            }
            // 40-bit
            if (p + 5 > end)
                return q;
            p += 5;
            return q;
        }

        bool SampleSplineAll(const SplineAnim& anim, float time, std::vector<Transform>& tracks)
        {
            tracks.clear();
            if (anim.blob.empty() || anim.ntracks <= 0)
                return false;
            int block = 0;
            if (anim.block_duration > 0.f && anim.nblocks > 0)
                block = std::clamp(static_cast<int>(time / anim.block_duration), 0, anim.nblocks - 1);
            if (block >= static_cast<int>(anim.block_offsets.size()))
                return false;
            const int end = static_cast<int>(anim.blob.size());
            int p = static_cast<int>(anim.block_offsets[static_cast<size_t>(block)]);
            const int mask_bytes = anim.ntracks * 2;
            if (p + mask_bytes > end)
                return false;
            const uint8_t* masks = anim.blob.data() + p;
            p += mask_bytes;
            p = Align(p, 4);
            const float local_frame = anim.max_frames > 1
                                          ? (time - static_cast<float>(block) * anim.block_duration) /
                                                std::max(0.0001f, anim.block_duration) *
                                                static_cast<float>(anim.max_frames - 1)
                                          : 0.f;

            tracks.resize(static_cast<size_t>(anim.ntracks));
            for (int t = 0; t < anim.ntracks; ++t) {
                const uint8_t quant = masks[t * 2];
                const uint8_t types = masks[t * 2 + 1];
                Transform xf{};
                xf.scale = {1, 1, 1};
                if (!ReadSplineVector(anim.blob.data(), p, end, types, 0, quant, 0.f, local_frame,
                        xf.translation.x, xf.translation.y, xf.translation.z))
                    return false;
                const Sub rot = SubType(types, 6);
                if (rot == Sub::Dynamic) {
                    if (p + 3 > end)
                        return false;
                    const int nitems = anim.blob[p];
                    p += 2;
                    const int degree = anim.blob[p++];
                    const int nknots = nitems + degree + 2;
                    p += nknots;
                    const int qtype = (quant >> 2) & 3;
                    if (qtype == 2)
                        p = Align(p, 2);
                    else if (qtype == 0 || qtype == 3)
                        p = Align(p, 4);
                    Quat last{0, 0, 0, 1};
                    for (int i = 0; i <= nitems; ++i)
                        last = ReadPackedQuat(anim.blob.data(), p, end, qtype);
                    xf.rotation = last;
                } else if (rot == Sub::Static) {
                    const int qtype = (quant >> 2) & 3;
                    xf.rotation = ReadPackedQuat(anim.blob.data(), p, end, qtype);
                }
                p = Align(p, 4);
                if (!ReadSplineVector(anim.blob.data(), p, end, types, 8, static_cast<uint8_t>(quant >> 4), 1.f,
                        local_frame, xf.scale.x, xf.scale.y, xf.scale.z))
                    return false;
                tracks[static_cast<size_t>(t)] = xf;
            }
            return true;
        }

        void FillWorld(const Skeleton& sk, const std::vector<Transform>& local, Pose& pose)
        {
            const size_t n = sk.bone_names.size();
            pose.world.resize(n);
            pose.name_index.clear();
            for (size_t i = 0; i < n; ++i) {
                const int p = i < sk.parents.size() ? sk.parents[i] : -1;
                if (p < 0)
                    pose.world[i] = local[i];
                else
                    pose.world[i] = Compose(pose.world[static_cast<size_t>(p)], local[i]);
                pose.name_index[BoneKey(sk.bone_names[i])] = static_cast<int>(i);
            }
        }
    }

    bool LoadSkeleton(const std::vector<uint8_t>& bytes, Skeleton& out)
    {
        std::vector<uint8_t> data;
        std::unordered_map<uint32_t, std::string> objects;
        if (!ParsePackfile(bytes, data, objects))
            return false;
        return ParseSkeleton(data, objects, out);
    }

    bool SampleAnimation(const std::vector<uint8_t>& anim_bytes, const Skeleton& skeleton, float t01, Pose& out)
    {
        std::vector<uint8_t> data;
        std::unordered_map<uint32_t, std::string> objects;
        if (!ParsePackfile(anim_bytes, data, objects))
            return false;
        SplineAnim anim;
        if (!ParseBindingAndAnim(data, objects, anim))
            return false;

        const size_t nbones = skeleton.bone_names.size();
        std::vector<Transform> local = skeleton.bind_local;
        local.resize(nbones);

        const float t = std::clamp(t01, 0.f, 1.f);
        if (!anim.interleaved.empty() && anim.ntracks > 0 && anim.nframes > 0) {
            int fr = static_cast<int>(t * static_cast<float>(anim.nframes - 1));
            fr = std::clamp(fr, 0, anim.nframes - 1);
            for (int tr = 0; tr < anim.ntracks; ++tr) {
                int bone = tr;
                if (tr < static_cast<int>(anim.track_to_bone.size()) && anim.track_to_bone[static_cast<size_t>(tr)] >= 0)
                    bone = anim.track_to_bone[static_cast<size_t>(tr)];
                const size_t idx = static_cast<size_t>(fr) * static_cast<size_t>(anim.ntracks) + static_cast<size_t>(tr);
                if (idx < anim.interleaved.size() && bone >= 0 && static_cast<size_t>(bone) < nbones)
                    local[static_cast<size_t>(bone)] = anim.interleaved[idx];
            }
        } else {
            const float time = t * anim.duration;
            std::vector<Transform> tracks;
            if (!SampleSplineAll(anim, time, tracks))
                return false;
            for (int tr = 0; tr < anim.ntracks; ++tr) {
                int bone = tr;
                if (tr < static_cast<int>(anim.track_to_bone.size()) && anim.track_to_bone[static_cast<size_t>(tr)] >= 0)
                    bone = anim.track_to_bone[static_cast<size_t>(tr)];
                if (bone < 0 || static_cast<size_t>(bone) >= nbones)
                    continue;
                if (tr < static_cast<int>(tracks.size()))
                    local[static_cast<size_t>(bone)] = tracks[static_cast<size_t>(tr)];
            }
        }
        FillWorld(skeleton, local, out);
        return !out.world.empty();
    }

    int FindBone(const Pose& pose, const std::string& name)
    {
        std::string k = name;
        std::transform(k.begin(), k.end(), k.begin(),
            [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        auto it = pose.name_index.find(k);
        if (it != pose.name_index.end())
            return it->second;
        return -1;
    }

    Vec3 BoneWorldPos(const Pose& pose, int bone)
    {
        if (bone < 0 || static_cast<size_t>(bone) >= pose.world.size())
            return {};
        return pose.world[static_cast<size_t>(bone)].translation;
    }
}
