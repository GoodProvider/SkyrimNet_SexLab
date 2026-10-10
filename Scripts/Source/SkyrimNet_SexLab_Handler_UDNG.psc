Scriptname SkyrimNet_SexLab_Handler_UDNG extends Quest

; Optional Devious Devices handler. zadLibs types must stay on this quest (Handler ESP)
; so the main ESP does not fail to bind when DD is absent.
; Per-actor WebUI session: JFormMap of original worn ids for narration. Pulldowns
; edit JS current only; Start applies currentJson then CloseOverlay. Hide/Cancel
; release the session without restoring devices (the actor was never mutated).

zadLibs zlibs = None
int group_devices = 0
int actor_bondage = 0

String group_devices_path = "Data/SKSE/Plugins/SkyrimNet_SexLab/bondage/group-devices.json"

Function Trace(String func, String msg, Bool notification=False) global
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_Handler_UDNG", func, msg)
    if notification
        Debug.Notification(msg)
    endif
EndFunction

Function Setup()
    ReleaseAll()
    Bool links_ok = Setup_CheckLinks()
    if !links_ok
        return
    endif

    String key_ = "SkyrimNet_SexLab_UDNG_MenuOpen"
    UnRegisterForModEvent(key_)
    RegisterForModEvent(key_, "MenuOpen")
    Trace("Setup", "--- DD Assets loaded, registered "+key_)
EndFunction

Bool Function Setup_CheckLinks()
    if Game.GetModByName("Devious Devices - Assets.esm") == 255
        Trace("Setup_CheckLinks", "--- Devious Devices - Assets.esm not loaded")
        return false
    endif
    if Game.GetModByName("Devious Devices - Integration.esm") == 255
        Trace("Setup_CheckLinks", "--- Devious Devices - Integration.esm not loaded")
        return false
    endif
    ; SKSE plugin name from DDNG CMake; equivalent to zadNativeFunctions.PluginInstalled("DeviousDevices.dll")
    ; without a Handler compile dep on zadNativeFunctions.
    if SKSE.GetPluginVersion("DeviousDevices") == 0
        Trace("Setup_CheckLinks", "--- DeviousDevices.dll not loaded (Devious Devices NG required for BondagePanel)")
        return false
    endif

    if zlibs == None
        zlibs = Game.GetFormFromFile(0x00F624, "Devious Devices - Integration.esm") as zadLibs
    endif
    if zlibs == None
        Trace("Setup_CheckLinks", "--- zadLibs 0xF624 missing from Integration.esm")
        return false
    endif

    if group_devices != 0
        JValue.release(group_devices)
        group_devices = 0
    endif
    group_devices = JValue.readFromFile(group_devices_path)
    if group_devices == 0
        Trace("Setup_CheckLinks", "--- failed to read "+group_devices_path)
        return false
    endif
    JValue.retain(group_devices)
    return true
EndFunction

Bool Function EnsureReady()
    if zlibs == None || group_devices == 0
        return Setup_CheckLinks()
    endif
    return true
EndFunction

Function OpenMenu(Actor target)
    TM_BondageRefresh(target)
EndFunction

Event MenuOpen(Form target_form)
    OpenMenu(target_form as Actor)
EndEvent

String Function DeviceStr(int device, String key1, String key2)
    String v = JMap.getStr(device, key1)
    if v != ""
        return v
    endif
    return JMap.getStr(device, key2)
EndFunction

String Function DeviceIdOf(int device)
    String id = DeviceStr(device, "id", "Id")
    if id != ""
        return id
    endif
    return DeviceStr(device, "name", "Name")
EndFunction

String Function DeviceNameOf(int device)
    String n = DeviceStr(device, "name", "Name")
    if n != ""
        return n
    endif
    return DeviceIdOf(device)
EndFunction

int Function HexToInt(String s)
    if s == ""
        return 0
    endif
    int start = 0
    if StringUtil.GetLength(s) >= 2
        String a = StringUtil.GetNthChar(s, 0)
        String b = StringUtil.GetNthChar(s, 1)
        if a == "0" && (b == "x" || b == "X")
            start = 2
        endif
    endif
    String digits = "0123456789abcdefABCDEF"
    int n = 0
    int i = start
    int len = StringUtil.GetLength(s)
    while i < len
        String c = StringUtil.GetNthChar(s, i)
        int d = StringUtil.Find(digits, c)
        if d < 0
            return 0
        endif
        if d > 15
            d -= 6
        endif
        n = n * 16 + d
        i += 1
    endwhile
    return n
EndFunction

Armor Function ArmorFromWantedId(String wantedId)
    if wantedId == ""
        return None
    endif
    int colon = StringUtil.Find(wantedId, ":")
    if colon < 0
        return None
    endif
    String plugin = StringUtil.Substring(wantedId, 0, colon)
    String hex = StringUtil.Substring(wantedId, colon + 1)
    int local = HexToInt(hex)
    if local <= 0 || plugin == ""
        return None
    endif
    return Game.GetFormFromFile(local, plugin) as Armor
EndFunction

Keyword Function DeviceKeywordOf(int device)
    Keyword kword = JMap.getForm(device, "keyword") as Keyword
    if kword == None
        kword = JMap.getForm(device, "Keyword") as Keyword
    endif
    return kword
EndFunction

Bool Function DeviceIsWorn(Actor target, int device)
    if target == None || zlibs == None || device <= 0
        return false
    endif
    Armor rendered = JMap.getForm(device, "formRendered") as Armor
    Keyword kword = DeviceKeywordOf(device)
    return 1 == zlibs.IsWearingDevice(target, rendered, kword)
EndFunction

int Function WornDeviceInGroup(Actor target, int devices)
    if devices == 0
        return 0
    endif
    int j = JArray.count(devices) - 1
    while j >= 0
        int device = JArray.getObj(devices, j)
        if DeviceIsWorn(target, device)
            return device
        endif
        j -= 1
    endwhile
    return 0
EndFunction

int Function FindDeviceById(int devices, String deviceId)
    if devices == 0 || deviceId == ""
        return 0
    endif
    int n = JArray.count(devices)
    int i = 0
    while i < n
        int device = JArray.getObj(devices, i)
        if DeviceIdOf(device) == deviceId
            return device
        endif
        i += 1
    endwhile
    return 0
EndFunction

Function AddKeys(Actor target, Key z_key, int num)
    if target == None || z_key == None
        return
    endif
    int need = num - target.GetItemCount(z_key)
    if need > 0
        target.AddItem(z_key, need, abSilent=True)
    endif
EndFunction

Function ReleaseAll()
    if actor_bondage != 0
        JValue.release(actor_bondage)
        actor_bondage = 0
    endif
EndFunction

int Function SessionOf(Actor target)
    if target == None || actor_bondage == 0
        return 0
    endif
    return JFormMap.getObj(actor_bondage, target)
EndFunction

Function EnsureSession(Actor target)
    if target == None
        return
    endif
    if actor_bondage == 0
        actor_bondage = JFormMap.object()
        JValue.retain(actor_bondage)
    endif
    if JFormMap.hasKey(actor_bondage, target)
        return
    endif
    ; Do not scan group-devices.json here — 750 IsWearingDevice calls stall the
    ; overlay on "loading…". Original worn comes from JS ActorBondage (C++ GetWornDevices).
    int session = JMap.object()
    JMap.setObj(session, "original", JArray.object())
    JFormMap.setObj(actor_bondage, target, session)
    Trace("EnsureSession", "--- seed "+GetDisplayNameSafe(target))
EndFunction

int Function BondageWantedMap(int payload)
    if payload == 0
        return 0
    endif
    int nested = JMap.getObj(payload, "current")
    if nested != 0
        return nested
    endif
    return payload
EndFunction

int Function BondageOriginalMap(int payload)
    if payload == 0
        return 0
    endif
    return JMap.getObj(payload, "original")
EndFunction

Function PushBondageState(Actor target)
    if target == None
        return
    endif
    int root = JMap.object()
    JMap.setInt(root, "target", target.GetFormID())
    String json = SkyrimNet_SexLab_Utilities.ObjectToLowerCaseKeyJson(root)
    JValue.release(root)
    Trace("PushBondageState", "--- formId="+target.GetFormID())
    SkyrimNet_SexLab_WebUI.Bondage_Configure(json)
EndFunction

Function TM_BondageRefresh(Actor target)
    if target == None
        Trace("TM_BondageRefresh", "--- target is None")
        return
    endif
    if !EnsureReady()
        Trace("TM_BondageRefresh", "--- DD not ready")
        return
    endif
    PushBondageState(target)
    EnsureSession(target)
EndFunction

int Function FileDeviceById(String deviceId)
    if group_devices == 0 || deviceId == ""
        return 0
    endif
    int n = JArray.count(group_devices)
    int i = 0
    while i < n
        int group = JArray.getObj(group_devices, i)
        int picked = FindDeviceById(JMap.getObj(group, "devices"), deviceId)
        if picked > 0
            return picked
        endif
        i += 1
    endwhile
    return 0
EndFunction

; Inventory armor for a catalog id: bundled file first, else straight from plugin:0xhex.
Armor Function InventoryOfId(String deviceId)
    Armor inv = None
    int d = FileDeviceById(deviceId)
    if d > 0
        inv = JMap.getForm(d, "formInventory") as Armor
    endif
    if inv == None
        inv = ArmorFromWantedId(deviceId)
    endif
    return inv
EndFunction

String Function DeviceLabel(String deviceId)
    if deviceId == ""
        return ""
    endif
    Armor inv = InventoryOfId(deviceId)
    if inv != None && inv.GetName() != ""
        return inv.GetName()
    endif
    return deviceId
EndFunction

; Unlock / lock / swap one slot by device id. Ids come from the live DD NG catalog, so
; group-devices.json only supplies optional rendered/keyword hints (speed), never a limit.
Bool Function ChangeDevice(Actor target, String origId, String wantedId)
    Armor origInv = None
    Armor origRendered = None
    Keyword origKw = None
    if origId != ""
        origInv = InventoryOfId(origId)
        int od = FileDeviceById(origId)
        if od > 0
            origRendered = JMap.getForm(od, "formRendered") as Armor
            origKw = DeviceKeywordOf(od)
        endif
        if origInv == None
            Trace("ChangeDevice", "--- cannot resolve current device "+origId)
            return false
        endif
    endif

    if wantedId == ""
        return zlibs.UnLockDevice(target, origInv, origRendered, origKw, destroyDevice = true)
    endif

    Armor wantedInv = InventoryOfId(wantedId)
    if wantedInv == None
        Trace("ChangeDevice", "--- cannot resolve wanted device "+wantedId)
        return false
    endif
    Keyword wantedKw = None
    int wd = FileDeviceById(wantedId)
    if wd > 0
        wantedKw = DeviceKeywordOf(wd)
    endif
    AddKeys(target, zlibs.chastityKey, 1)
    AddKeys(target, zlibs.restraintsKey, 2)
    AddKeys(target, zlibs.piercingKey, 1)
    if origId == ""
        return zlibs.LockDevice(target, wantedInv, force = true)
    endif
    return zlibs.SwapDevices(target, wantedInv, wantedKw, destroyDevice = true)
EndFunction

Function TM_BondageApply(Actor target, String deviceId)
    Trace("TM_BondageApply", "--- "+GetDisplayNameSafe(target)+" deviceId:"+deviceId)
    if target == None || deviceId == ""
        return
    endif
    if !EnsureReady()
        return
    endif
    EnsureSession(target)

    AddKeys(target, zlibs.chastityKey, 1)
    AddKeys(target, zlibs.restraintsKey, 2)
    AddKeys(target, zlibs.piercingKey, 1)

    int n = JArray.count(group_devices)
    int i = 0
    int picked = 0
    int devices = 0
    while i < n && picked == 0
        int group = JArray.getObj(group_devices, i)
        devices = JMap.getObj(group, "devices")
        picked = FindDeviceById(devices, deviceId)
        i += 1
    endwhile
    if picked <= 0
        ; Not in the bundled file: lock it straight from plugin:0xhex.
        Armor direct = ArmorFromWantedId(deviceId)
        if direct == None
            Trace("TM_BondageApply", "--- device not in catalog: "+deviceId)
            PushBondageState(target)
            return
        endif
        Bool lockedOk = zlibs.LockDevice(target, direct, force = true)
        Trace("TM_BondageApply", "--- lock (by id) "+deviceId+" ok="+lockedOk)
        PushBondageState(target)
        return
    endif

    int wearing = WornDeviceInGroup(target, devices)
    Armor inventory = JMap.getForm(picked, "formInventory") as Armor
    Armor rendered = JMap.getForm(picked, "formRendered") as Armor
    Keyword kword = DeviceKeywordOf(picked)

    Bool success = false
    if wearing > 0 && DeviceIdOf(wearing) == deviceId
        success = zlibs.UnLockDevice(target, inventory, rendered, destroyDevice = true)
        Trace("TM_BondageApply", "--- unlock "+deviceId+" ok="+success)
    elseif wearing <= 0
        success = zlibs.LockDevice(target, inventory, force = true)
        Trace("TM_BondageApply", "--- lock "+deviceId+" ok="+success)
    else
        success = zlibs.SwapDevices(target, inventory, kword, destroyDevice = true)
        Trace("TM_BondageApply", "--- swap to "+deviceId+" ok="+success)
    endif

    PushBondageState(target)
EndFunction

Function TM_BondageOnWebUIClosed()
    Trace("TM_BondageOnWebUIClosed", "--- release session")
    ReleaseAll()
EndFunction

Function TM_BondageFinish(Actor speaker, Actor target, String style, String currentJson)
    Trace("TM_BondageFinish", "--- "+GetDisplayNameSafe(speaker)+" -> "+GetDisplayNameSafe(target)+" style:"+style)
    Trace("TM_BondageFinish", "--- payload "+StringUtil.Substring(currentJson, 0, 600))
    if target == None || !EnsureReady()
        ReleaseAll()
        SkyrimNet_SexLab_WebUI.WebUI_CloseOverlay()
        return
    endif
    EnsureSession(target)

    int payload = 0
    if currentJson != ""
        payload = JValue.objectFromPrototype(currentJson)
    endif
    int wantedMap = BondageWantedMap(payload)
    int origMap = BondageOriginalMap(payload)

    String added = ""
    String removed = ""
    String failed = ""

    ; Iterate the payload's groups (the live DD NG catalog the panel showed), not
    ; group-devices.json: the bundled file lacks devices the panel can list and wear.
    String[] origNames = JMap.allKeysPArray(origMap)
    String[] wantedNames = JMap.allKeysPArray(wantedMap)
    int pass = 0
    while pass < 2
        String[] names = origNames
        if pass == 1
            names = wantedNames
        endif
        int n = 0
        if names
            n = names.Length
        endif
        int i = 0
        while i < n
            String gname = names[i]
            i += 1
            if pass == 0 || !JMap.hasKey(origMap, gname)
                String origId = JMap.getStr(origMap, gname)
                String wantedId = origId
                if JMap.hasKey(wantedMap, gname)
                    wantedId = JMap.getStr(wantedMap, gname)
                endif
                if origId != wantedId
                    Bool ok = ChangeDevice(target, origId, wantedId)
                    Trace("TM_BondageFinish", "--- "+gname+" '"+origId+"' -> '"+wantedId+"' ok="+ok)
                    String newLabel = DeviceLabel(wantedId)
                    String oldLabel = DeviceLabel(origId)
                    if !ok
                        if failed != ""
                            failed = failed + ", "
                        endif
                        if wantedId != ""
                            failed = failed + newLabel
                        else
                            failed = failed + oldLabel
                        endif
                    else
                        if origId != ""
                            if removed != ""
                                removed = removed + ", "
                            endif
                            removed = removed + oldLabel
                        endif
                        if wantedId != ""
                            if added != ""
                                added = added + ", "
                            endif
                            added = added + newLabel
                        endif
                    endif
                endif
            endif
        endwhile
        pass += 1
    endwhile

    if failed != ""
        Debug.Notification("Bondage: could not change "+failed)
    endif

    if style != "silently" && style != "silent"
        String style_desc = ""
        if style == "forcefully"
            style_desc = " forcefully "
        elseif style == "gently"
            style_desc = " gently "
        else
            style_desc = " "
        endif

        Actor who = speaker
        if who == None
            who = Game.GetPlayer()
        endif
        String msg = ""
        if removed != ""
            msg = msg + who.GetDisplayName()+style_desc+"unlocked and removed from "+target.GetDisplayName() \
                +" the following: "+removed+". "
        endif
        if added != ""
            msg = msg + who.GetDisplayName()+style_desc+"locked onto "+target.GetDisplayName() \
                +" the following: "+added+". "
        endif
        if msg != ""
            Debug.Notification(msg)
            ; Runs from the overlay (paused): queued and sent once the game unpauses.
            SkyrimNet_SexLab_Utilities.SendDirectNarration(msg, who, target)
        endif
    endif

    ReleaseAll()
    SkyrimNet_SexLab_WebUI.WebUI_CloseOverlay()
EndFunction

String Function GetDisplayNameSafe(Actor a)
    if a == None
        return "None"
    endif
    return a.GetDisplayName()
EndFunction
