#pragma once

#include <thread>
#include <utility>

#include "RE/Skyrim.h"
#include "SKSE/SKSE.h"

namespace TaskPost {

/// AddTask from a main-thread entry point (an input sink, a Papyrus native). On Skyrim VR, SKSE drains its task
/// queue on game job threads while holding the queue lock, so an AddTask from the main thread can wait on a job
/// that waits for the frame (MagelightUI_API.h threading contract): post from a thread of our own there.
/// Inside an SKSE task or a Magelight PostGameTask body, AddTask directly is safe (same drain).
template <class F>
void FromEntryPoint(F&& fn)
{
    auto* tasks = SKSE::GetTaskInterface();
    if (!tasks)
        return;
    if (REL::Module::IsVR()) {
        std::thread([tasks, f = std::forward<F>(fn)]() mutable { tasks->AddTask(std::move(f)); }).detach();
    } else {
        tasks->AddTask(std::forward<F>(fn));
    }
}

}  // namespace TaskPost
