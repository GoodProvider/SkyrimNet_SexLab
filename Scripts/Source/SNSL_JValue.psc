;/  Common functionality for SNSL_JMap / SNSL_JArray / SNSL_JFormMap, backed by a C++ store in
    this mod's own SKSE plugin (SKSE_Source/src/JsonStore.h) instead of JContainers.

    Why this exists instead of JContainers: see KNOWLEDGEBASE.md "Papyrus VM silently returns
    None under overlay pause" -- JContainers garbage-collects unowned temporary objects on a ~10s
    lifetime, and the old Papyrus JSON walker (SkyrimNet_SexLab_Utilities.psc) took ~9s to
    serialize a live scene payload, so JC destroyed the object tree mid-walk. This store has no
    garbage collector: a node lives until its owning root is released or the game exits.

    Signatures mirror JValue's so a call site can migrate with a straight `JValue.` ->
    `SNSL_JValue.` rename. Two additions beyond JContainers' own API:
      dump(object) -- serializes the whole tree in one native call (replaces the Papyrus walker).
      stats() -- diagnostic: live/root/free slot counts, logged automatically past 4096 roots.
/;
ScriptName SNSL_JValue

;/  NOT a no-op. There is no garbage collector, but retain marks @object as independently owned,
    which changes how attaching it behaves: setObj/addObj of an unowned, retained handle stores a
    deep COPY (later writes to @object don't reach the container). A retained child that gets
    detached (clear/removeKey/overwrite) survives, and re-attaching it copies too.
    Rule: attach first, then retain. Only retain an unattached root that you want the container to
    snapshot (e.g. Scene_Manager's last_ended_obj). Logs a warning if @object is already dead.
/;
Int function retain(Int object, String tag="") global native

;/  Releases a root object (frees its whole subtree). A no-op if @object is still owned by another
    container (matches JContainers: a live container's contents are never destroyed out from under
    it). Always returns 0, so `object = SNSL_JValue.release(object)` reads the same as before.
/;
Int function release(Int object) global native

;/  Releases @previousObject, retains and returns @newObject.
/;
Int function releaseAndRetain(Int previousObject, Int newObject, String tag="") global native

;/  Tests whether given object identifier refers to a live node (not stale/never-allocated/from a
    prior save).
/;
Bool function isExists(Int object) global native

Bool function isArray(Int object) global native
Bool function isMap(Int object) global native
Bool function isFormMap(Int object) global native
;/  Always False -- this store has no integer-keyed map type. JIntMap (JContainers) is unaffected
    and still usable for anything not yet migrated.
/;
Bool function isIntegerMap(Int object) global native

;/  Returns amount of items in the container (0 if @object is not a live container).
/;
Int function count(Int object) global native

;/  Creates a new container object using given JSON string-prototype. Object keys are lowercased
    (ASCII) as the tree is built. Returns 0 on parse failure (logged).
/;
Int function objectFromPrototype(String prototype) global native

;/  Creates and returns a new container object containing the contents of a JSON file.
/;
Int function readFromFile(String filePath) global native

;/  Serializes @object and writes it to a JSON file.
/;
function writeToFile(Int object, String filePath) global native

;/  Serializes @object to a compact JSON string in a single native call. Object keys are already
    lowercase (set on insert), so unlike the old Utilities.psc walker this needs no separate
    lower-casing pass. Returns "" if @object is not a live container.
/;
String function dump(Int object) global native

;/  Diagnostic snapshot: "slots=N live=N roots=N free=N session=N reparentCopies=N".
/;
String function stats() global native
