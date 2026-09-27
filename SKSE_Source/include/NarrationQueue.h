#pragma once

#include "PCH.h"

#include <string>

/// DirectNarrations sent while the game is paused (WebUI overlay with pause, or any pausing menu)
/// make SkyrimNet block every Papyrus decorator, so NPC responses fail. Papyrus queues them here;
/// once the game is unpaused they are joined into one DirectNarration sent through Papyrus
/// SkyrimNet_SexLab_Utilities.DirectNarration_Flush.
namespace NarrationQueue
{
    /// True while the overlay pauses the game or a menu pauses it.
    bool IsPaused();

    /// Queues msg when paused and starts the unpause watcher. False (not queued) when not paused.
    bool Enqueue(const std::string& msg, RE::Actor* source, RE::Actor* target, bool purge_dialogue);

    /// Drops the queue (load / new game): narrations belong to the session that made them.
    void Clear();
}
