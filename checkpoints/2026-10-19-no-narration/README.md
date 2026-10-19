User says: 
    Delicious Nuts — 5:18 AM
    the direct narrations are definetly not working- at least for me. not on start, end, or anything.
    new game- started scene with hotkey- target (hulda), with (prisoner) , selected player was in giving position but the dialogue was making hulda fuck the player. When i started- no dialogue for a good bit, ending dialogue was there though. Another thing I wanted to ask, it this mod add a tongue out to receivers? cause i see there always now, maybe it is from better expression mod lol.

I have copied the logs into the logs directory of this README.md 

I suspect we need to shrink maximum silence window, the amount of silence before SkyrimNet_SexLa generates a 'continue narration'.
Review the updated API ../skyrimnet devkit/ to see if there is a better way to tell skyrimnet to continue narration with the actors in the a scene. 