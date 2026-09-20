#pragma once

#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

namespace HkxAnim
{
    struct Vec3
    {
        float x = 0.f;
        float y = 0.f;
        float z = 0.f;
    };

    struct Quat
    {
        float x = 0.f;
        float y = 0.f;
        float z = 0.f;
        float w = 1.f;
    };

    struct Transform
    {
        Vec3 translation;
        Quat rotation;
        Vec3 scale{1.f, 1.f, 1.f};
    };

    struct Skeleton
    {
        std::vector<std::string> bone_names;
        std::vector<int16_t> parents;
        std::vector<Transform> bind_local;
    };

    struct Pose
    {
        /// World-space bone transforms, same order as skeleton.bone_names.
        std::vector<Transform> world;
        std::unordered_map<std::string, int> name_index;
    };

    bool LoadSkeleton(const std::vector<uint8_t>& bytes, Skeleton& out);
    /// Sample animation at t in [0,1] of duration (0.5 = mid-clip). pose.world matches skeleton bones.
    bool SampleAnimation(const std::vector<uint8_t>& anim_bytes, const Skeleton& skeleton, float t01,
        Pose& out);
    int FindBone(const Pose& pose, const std::string& name);
    Vec3 BoneWorldPos(const Pose& pose, int bone);
}
