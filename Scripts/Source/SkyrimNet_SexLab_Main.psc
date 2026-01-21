Scriptname SkyrimNet_SexLab_Main extends Quest

import JContainers
import UIExtensions
import SkyrimNet_SexLab_Decorators
import SkyrimNet_SexLab_Actions
import SkyrimNet_SexLab_Stages
import SkyrimNet_SexLab_Utilities
import StorageUtil

; ---------------------------------------------------
; Globals 
; ---------------------------------------------------

; SexLab Active Sex 
; 0 - no active sexlab animations 
; 1 - one or more active sexlab animations
GlobalVariable Property skyrimnet_sexlab_active_sex Auto
Bool Property active_sex 
    Bool Function Get()
        return skyrimnet_sexlab_active_sex.GetValueInt() == 1
    EndFunction 
    Function Set(Bool value)
        if value
            skyrimnet_sexlab_active_sex.SetValue(1.0)
        else
            skyrimnet_sexlab_active_sex.SetValue(0.0)
        endif
    EndFunction 
EndProperty

; ----- Does all animations -----
; Sexlab or Ostim animation with player
; 0 - Sexlab
; 1 - Ostim
; 2 - Choose per animation
GlobalVariable Property skyrimnet_sexlab_ostim_player Auto
int Property sexlab_ostim_player_index
    int Function Get()
        return skyrimnet_sexlab_ostim_player.GetValueInt()
    EndFunction 
    Function Set(int value)
        skyrimnet_sexlab_ostim_player.SetValue(value)
        OstimNet_Reset() 
    EndFunction 
EndProperty

; ----- Not currently supported ------
; Sexlab or Ostim animation without player
; 0 - Sexlab
; 1 - Ostim
; 2 - Choose per animation
GlobalVariable Property skyrimnet_sexlab_ostim_nonplayer Auto
int Property sexlab_ostim_nonplayer_index
    int Function Get()
        return skyrimnet_sexlab_ostim_nonplayer.GetValueInt()
    EndFunction 
    Function Set(int value)
        skyrimnet_sexlab_ostim_nonplayer.SetValue(value)
        OstimNet_Reset() 
    EndFunction 
EndProperty

; ---------------------------------------------------

ReferenceAlias[] Property nude_refs Auto


int Property BUTTON_YES = 0 Auto        ; 0
int Property BUTTON_YES_RANDOM = 1 Auto ; 1
int Property BUTTON_NO_SILENT = 2 Auto  ; 2
int Property BUTTON_NO = 3 Auto         ; 3

int Property STYLE_FORCEFULLY = 0 Auto 
int Property STYLE_NORMALLY = 1 Auto 
int Property STYLE_GENTLY = 2 Auto 
int Property STYLE_SILENTLY = 3 Auto 
int[] thread_style
bool[] thread_started


Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Main."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

bool Property rape_allowed = true Auto
bool Property sex_edit_tags_player = true Auto 
bool Property sex_edit_tags_nonplayer = False Auto

int Property actorLock = 0 Auto 
float Property actorLockTimeout = 0.00069444444 Auto ;  1 day / (24 hours  * 60 minutes ) 

int Property group_info = 0 Auto
int Property group_ordered = 0 Auto

int skynet_tag_sex_lock = 0 

String Property storage_items_key = "skyrimnet_sexlab_storage_items" Auto
String Property storage_arousal_key = "skyrimnet_sexlab_arousal_level" Auto
String Property storage_thread_ejaculated = "skyrimnet_sexlab_thread_ejaculated" Auto

SkyrimNet_SexLab_Stages Property stages Auto
SexLabFramework Property sexlab Auto 

; -----------------------------
; DOM found 
; -----------------------------
bool Property dom_main_found Auto
Quest Property dom_main Auto 

; -----------------------------
; Cuddle found 
; -----------------------------
bool Property cuddle_found Auto

string actor_num_orgasms_key = "skyrimnet_sexlab_actor_num_orgasms"
string actor_thread_id = "skyrimnet_sexlab_actor_thread_id"
; Stores if SLSO.esp is found

; Controls when Direction Narration occur 
float Property direct_narration_cool_off Auto 
float Property direct_narration_max_distance Auto 
float Property direct_narration_max_distance_default Auto 

; OstimNet 
bool ostimnet_found = false 

; Race to speech 
int Property race_to_description Auto

int Property counter Auto 

Event OnInit()
    Trace("OnInit","")
    rape_allowed = true

    ; Register for all SexLab events using the framework's RegisterForAllEvents function
    Setup() 
EndEvent

Function Setup()
    Trace("SetUp","")
        
    ; Setup the enable if found 
    if MiscUtil.FileExists("Data/TT_OStimNet.esp")
        ostimnet_found = true 
    else 
        ostimnet_found = false 
    endif 
    Trace("Setup","OstimNet found "+ostimnet_found)
    OstimNet_Reset() 

    thread_started = new bool[32]
    if thread_style.length == 0 
        thread_style = new int[32] 
        thread_started = new bool[32]
        int j = thread_style.length - 1 
        while 0 <= j 
            thread_style[j] = STYLE_NORMALLY
            thread_started[j] = false 
            j -= 1 
        endwhile 
    endif 

    if !MiscUtil.FileExists("Data/SexLab.esm")
        Trace("SetUp","Data/SexLab.esm does not exist") 
        Debug.MessageBox("Can't find Data/SexLab.esm\n"\
            +"SkyrimNet_SexLab will not work.")
        return 
    endif 
    SexLab = Game.GetFormFromFile(0xD62, "SexLab.esm") as SexLabFramework


    ; SkyrimNet DOM 
    if MiscUtil.FileExists("Data/SkyrimNet_DOM.esp")
        dom_main = Game.GetFormFromFile(0x800, "SkyrimNet_DOM.esp") as Quest
        dom_main_found = True
    else 
        dom_main = None 
        dom_main_found = False
    endif 

    ; SkyrimNet Cuddle 
    if MiscUtil.FileExists("Data/SkyrimNet_Cuddle.esp")
        cuddle_found = True
    else 
        cuddle_found = False
    endif 

    ; Set up the Buttons 
    BUTTON_YES = 0 
    BUTTON_YES_RANDOM = 1
    BUTTON_NO_SILENT = 2 
    BUTTON_NO = 3

    ; Setup related Scripts 
    if stages == None
        stages = (self as Quest) as SkyrimNet_SexLab_Stages
    endif 
    stages.Setup() 
    skyrimnet_sexlab_active_sex = Game.GetformFromFile(0x802, "SkyrimNet_SexLab.esp") as GlobalVariable
    active_sex = false

    SkyrimNet_SexLab_MCM mcm = (self as Quest) as SkyrimNet_SexLab_MCM
    mcm.Setup() 

    ; Directy Narration 
    if direct_narration_cool_off == 0 
        direct_narration_cool_off = 20 
        direct_narration_max_distance = 15
        direct_narration_max_distance_default = 15
    endif 

    if actorLock == 0 
        actorLock = JFormMap.object() 
        JValue.retain(actorLock)
        ActorLockTimeout = 60.0
    elseif JFormMap.count(actorLock) > 0
        Form[] forms = JFormMap.allKeysPArray(actorLock)
        if forms != None 
            int i = forms.Length
            while i >= 0
                ReleaseActorLock(forms[i] as Actor)
                i -= 1
            endwhile 
        endif
    endif 

    if group_info == 0
        group_info = JValue.readFromFile("Data/SKSE/Plugins/SkyrimNet_Sexlab/group_tags.json")
        JValue.retain(group_info)
    else
        int group_info_new = JValue.readFromFile("Data/SKSE/Plugins/SkyrimNet_Sexlab/group_tags.json")
        Jvalue.releaseAndRetain(group_info, group_info_new)
        group_info = group_info_new
    endif

    if race_to_description <= 0 
        race_to_description = JValue.readFromFile("Data/SKSE/Plugins/SkyrimNet_Sexlab/creatures.json")
        JValue.retain(race_to_description)
    endif 

    RegisterSexlabEvents()
    SkyrimNet_SexLab_Actions.RegisterActions()
    SkyrimNet_SexLab_Decorators.RegisterDecorators() 
EndFunction


Function OstimNet_Reset() 
    if ostimnet_found
        if sexlab_ostim_player_index == 1 
            Trace("OstimNet_Reset","enabling StartNewSex")
            TTON_JData.SetStartNewSexEnable(1)
        else 
            Trace("OstimNet_Reset","disabling StartNewSex")
            TTON_JData.SetStartNewSexEnable(0)
        endif 
    endif 
EndFunction 

;----------------------------------------------------------------------------------------------------
; Stripped Items Storage
;----------------------------------------------------------------------------------------------------

Function StoreStrippedItems(Actor akActor, Form[] forms)
    if akActor == None || forms.Length == 0
        return 
    endif 
    Trace("AddStrippedItems",akActor.GetDisplayName()+" num_items:"+forms.Length)
    StorageUtil.FormListClear(akActor, storage_items_key)
    int i = 0
    while i < forms.Length
        StorageUtil.FormListAdd(akActor, storage_items_key, forms[i])
        i += 1
    endwhile

    i = nude_refs.Length - 1
    while 0 <= i 
        if nude_refs[i].GetActorReference() == None 
            nude_refs[i].ForceRefTo(akActor) 
            i = -1
        endif 
        i -= 1 
    endwhile 
EndFunction 

Form[] Function UnStoreStrippedItems(Actor akActor)
    Trace("UnStoreStrippedItems",akActor.GetDisplayName()+" attempting to undress")
    int i = nude_refs.length - 1
    while 0 <= i 
        if nude_refs[i].GetActorReference() == akActor 
            nude_refs[i].Clear() 
            Utility.Wait(1.00)
            i = -1
        endif 
        i -= 1 
    endwhile 
    if !HasStrippedItems(akActor)
        return None
    endif
    Form[] forms = StorageUtil.FormListToArray(akActor, storage_items_key)
    StorageUtil.FormListClear(akActor, storage_items_key)
    return forms
EndFunction

Bool Function HasStrippedItems(Actor akActor)
    if akActor == None || StorageUtil.FormListCount(akActor, storage_items_key) == 0
        return False
    endif 
    return true 
EndFunction

;----------------------------------------------------------------------------------------------------
; Actor Lock
;----------------------------------------------------------------------------------------------------

bool Function LockActors(Actor[] actors) 
    int i = actors.length - 1 
    while 0 <= i && SetActorLock(actors[i]) 
        i -= 1 
    endwhile 

    if i > -1 
        int j = i 
        int count = actors.length - 1 
        while j < count 
            ReleaseActorLock(actors[j]) 
            j += 1 
        endwhile 
        return False 
    endif 
    return True 
EndFunction 

bool Function UnLockActors(Actor[] actors) 
    int i = actors.length - 1 
    while 0 <= i 
        ReleaseActorLock(actors[i]) 
        i -= 1 
    endwhile 
EndFunction 

Bool Function IsActorLocked(Actor akActor) 
    bool locked = False
    if akActor != None 
        if JFormMap.hasKey(actorLock, akActor) 
            float time = JFormMap.getFlt(actorLock, akActor) 
            if Utility.GetCurrentGameTime() - time > actorLockTimeout
                JFormMap.removeKey(actorLock, akActor)
                locked = False
            else
                locked = True
            endif 
        endif 
        Trace("IsActorLocked",akActor.GetDisplayName()+" "+locked)
    endif 
    return locked 
EndFunction

bool Function SetActorLock(Actor akActor) 
    if akActor == None || IsActorLocked(akActor)
        return false 
    endif 
    Trace("SetActorLock",akActor.GetDisplayName())
    JFormMap.setFlt(actorLock, akActor, Utility.GetCurrentGameTime())
    return true
EndFunction

Function ReleaseActorLock(Actor akActor) 
    if akActor == None 
        return 
    endif 
    Trace("ReleaseActorLock",akActor.GetDisplayName())
    JFormMap.removeKey(actorLock, akActor)
EndFunction

;----------------------------------------------------------------------------------------------------
;Function SetThreadEjaculated(Actor akActor, int cum_added) 
    ;int value = 0 
    ;if ejaculated
        ;value = 1
    ;endif 
    ;StorageUtil.SetIntValue(thread, storage_thread_ejaculated, value)
;EndFunction 

;bool Function GetThreadEjaculated(sslThreadController thread) 
    ;1 == StorageUtil.GetIntValue(thread, storage_thread_ejaculated, 0)
;EndFunction 

;----------------------------------------------------------------------------------------------------
Function SetThreadStyle(int thread_id, int style) 
    thread_style[thread_id] = style 
EndFunction

Int Function GetThreadStyle(int thread_id)
    return thread_style[thread_id]
EndFunction

String Function GetThreadStyleString(int thread_id)
    int style = thread_style[thread_id]
    if style == STYLE_FORCEFULLY
        return "forcefully"
    elseif style == STYLE_NORMALLY
        return "normally"
    elseif style == STYLE_GENTLY
        return "gently"
    elseif style == STYLE_SILENTLY
        return "silently"
    endif 
    return "normally"
EndFunction

;----------------------------------------------------------------------------------------------------
bool Function Tag_SexAnimation(Actor akActor) 
    if akActor == None 
        return false 
    endif 
    if MiscUtil.FileExists("Data/SexLab.esm") 
        return sexlab.AnimSlots.IsRegistered(akActor)
    endif
    return false
EndFunction

;----------------------------------------------------------------------------------------------------
sslThreadController Function GetThread(Actor akActor) 
    sslThreadController thread = None
    int thread_id = StorageUtil.GetIntValue(akActor, actor_thread_id, -1)
    if SexLab != None && thread_id != -1 
        thread = SexLab.GetController(thread_id)
    endif 
    
    if thread == None 
        Trace("GetThread","Failed to find thread for actor "+akActor.GetDisplayName())
       sslThreadSlots ThreadSlots = (SexLab as Quest) as sslThreadSlots
        if ThreadSlots == None
            Trace("Get_Threads","ThreadSlots is None",true)
            return None
        endif

        sslThreadController[] threads = ThreadSlots.Threads
        int i = threads.length - 1
        while 0 <= i && thread == None
            Actor[] actors = threads[i].Positions
            int j = actors.length - 1
            while 0 <= j && thread == None
                if actors[j] == akActor
                    thread = threads[i]
                endif 
                j -= 1
            endwhile 
            i -= 1
        endwhile
        if thread != None
            Trace("GetThread","Failed to find thread for actor "+akActor.GetDisplayName()+" then found/storing "+thread.tid+" by searching all threads")
            StorageUtil.SetIntValue(akActor, actor_thread_id, thread.tid)
        endif 
    endif 
    return thread 
EndFunction

;----------------------------------------------------------------------------------------------------
; SexLab Events
;----------------------------------------------------------------------------------------------------
Function RegisterSexlabEvents() 
    Trace("RegisterSexlabEvents","")
    ; SexLabFramework sexlab = Game.GetForm

    UnRegisterForModEvent("HookAnimationStart")
    RegisterForModEvent("HookAnimationStart", "AnimationStart")
    UnRegisterForModEvent("HookStageStart")
    RegisterForModEvent("HookStageStart", "StageStart")
    ;UnRegisterForModEvent("HookStageEnd")
    ;RegisterForModEvent("HookStageEnd", "SexLab_StageEnd")
    UnRegisterForModEvent("HookAnimationEnd")
    RegisterForModEvent("HookAnimationEnd", "AnimationEnd")

    UnRegisterForModEvent("HookOrgasmStart")
    UnRegisterForModEvent("SexLabOrgasm")
    RegisterForModEvent("SexLabOrgasm", "Orgasm_Individual")
    UnRegisterForModEvent("HookOrgasmStart")
    RegisterForModEvent("HookOrgasmStart", "Orgasm_Combined")

EndFunction 

event AnimationStart(int ThreadID, bool HasPlayer)
    Trace("AnimationStart","ThreadID:"+ThreadID+" HasPlayer:"+HasPlayer)
    if SexLab == None
        return  
    endif
    sslThreadController thread = SexLab.GetController(ThreadID)
    Actor[] actors = thread.Positions

    SkyrimNet_SexLab_Decorators.Save_Threads(SexLab)
    if (HasPlayer && sex_edit_tags_player) || (!HasPlayer && sex_edit_tags_nonplayer)
        SexStyleDialog(thread) 
    endif 
    SkyrimNet_SexLab_Decorators.Save_Threads(SexLab)

    int i = actors.length - 1
    while 0 <= i 
        ReleaseActorLock(actors[i])
        i -= 1
    endwhile 

    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    if config.SeparateOrgasms
        actors = thread.Positions
        int j = actors.length - 1 
        while 0 <= j 
            Trace("AnimationStart","actor:"+actors[j].GetDisplayName()+" reset num orgasm and storing thread_id")
            StorageUtil.SetIntValue(actors[j], actor_num_orgasms_key, 0)
            StorageUtil.SetIntValue(actors[j], actor_thread_id, ThreadID)
            j -= 1 
        endwhile 
    endif 

    sslActorLibrary actorLib = (SexLab as Quest) as sslActorLibrary
    String desc = Get_Thread_Description(thread, actorLib)
    Actor target = None 
    if actors.length > 2 && actors[0] != actors[1]
        target = actors[1]
    endif
    active_sex = true
    DirectNarration(desc, actors[0], target)
    thread_started[thread.tid] = False 
endEvent
        
Function StartStop_DirectNarration(sslThreadController thread, String status, Bool HasPlayer)
    Actor[] actors = thread.Positions
    String narration = Thread_Narration(thread, status)
    Actor target = None
    if actors.length >= 2 && actors[0] != actors[1]
        target = actors[1]
    endif 
    ;String name = "None"
    ;if target != None
        ;name = target.GetDisplayName()
    ;endif
    ;Trace("StartStop_DirectNarration","status:"+status+" narration:"+narration+" actors.length:"+actors.length+" target:"+name)
    if status == "start"
        if HasPlayer
            DirectNarration(narration, actors[0], target)
        else
            DirectNarration_Optional("sexlab_event", narration, actors[0], target)
        endif
    else
        RegisterEvent("sexlab_event", narration, actors[0], target)
    endif 
EndFunction

Event StageStart(int ThreadID, bool HasPlayer)
    if SexLab == None
        return  
    endif
    sslActorLibrary actorLib = (SexLab as Quest) as sslActorLibrary

    sslThreadController thread = SexLab.GetController(ThreadID)
    Actor[] actors = thread.Positions

    Actor target = None 
    if actors.length > 2 && actors[0] != actors[1]
        target = actors[1]
    endif 

    ; Set up the thread's description
    ;DirectNarration(desc, actors[0], target)

    SkyrimNet_SexLab_Decorators.Save_Threads(SexLab)

    ; Send a DN if its a start and includes a player
    ; if not player send DN if allowedb by cool off 
    String event_type = "sexlab_event"
    if !thread_started[ThreadID]
        thread_started[ThreadID] = True 
        ;AllowedDeniedOnlyIncrease(actors, thread, "start") 
        ;StartStop_DirectNarration(thread,"start", HasPlayer)
        ;DirectNarration(desc, actors[0], target)
    else 
        String desc = Get_Thread_Description(thread, actorLib)
        ContinueScene(actors[0], target, True)
    endif 

    ;AllowedDeniedOnlyIncrease(thread.positions, thread, "stage") 

    Actor sender = actors[0] 
    Actor reciever = None 
    if actors.length > 1 
        reciever = actors[1] 
    endif 

    ; If this thread is being tracked print the thread's status 
    if stages.IsThreadTracking(ThreadID)
        bool[] desc_orgasm = stages.GetHasDescriptionOrgasmExpected(thread)
        String msg = "" 
        if desc_orgasm[0]
            msg = "has description"
        endif
        if desc_orgasm[1]
            if msg != ""
                msg += " and "
            endif 
            msg += "orgasm expected"        
        endif
        Debug.Notification("stage "+thread.stage+" of "+ thread.animation.StageCount()+" "+msg)
    endif 

    ; DOM Slaves have thier own orasm system 
    ; if dom_main != None 
        ; int k = actors.length - 1
        ; while 0 <= k 
            ; DOM_Actor slave = SkyrimNet_DOM_Utils.GetSlave("SkyrimNet_SexLab_Main","Start_Sex",actors[k],true,true)
            ; Debug.Notification("slave:"+slave)
            ; if (dom_main as SkyrimNet_DOM_Main).IsDomSlave(actors[k]) 
                ; Debug.Notification(actors[k].GetDisplayName()+" denied")
            ; else
                ; Debug.Notification(actors[k].GetDisplayName()+" allowed")
            ; endif 
            ; k -= 1 
        ; endwhile
    ; endif 
EndEvent


event AnimationEnd(int ThreadID, bool HasPlayer)
    Trace("AnimationEnd","ThreadID:"+ThreadID+" HasPlayer:"+HasPlayer)
    ; String desc = stages.GetStageDescription(SexLab.GetController(ThreadID))
    ; if desc != ""
        ; Actor[] actors = SexLab.GetController(ThreadID).Positions
        ; desc = stages.Description_Add_Actors(s, desc)
        ; Skyrim
    ; endif 

    sslThreadController thread = SexLab.GetController(ThreadID)
    
    ; Handle Separate Orgasms
    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    Actor[] actors = thread.Positions
    String[] names = Utility.CreateStringArray(actors.length)
    String[] nouns = Utility.CreateStringArray(0)
    int i = actors.length - 1
    while 0 <= i 
        names[i] = actors[i].GetDisplayName()
        i -= 1
    endwhile
    String narration = SkyrimNetAPI.JoinStrings(names, nouns)
    if actors.length > 2
        narration += " stop having sex."
    else
        narration += " stops having sex."
    endif 

    bool orgasm_denied = false
    Actor target = None
    if config.SeparateOrgasms
        String after = "" 
        if actors.length > 2 && actors[0] != actors[1]
            target = actors[1]
        endif 
        int[] orgasm_expected = stages.GetOrgasmExpected(thread)
        int j = actors.length - 1 
        while 0 <= j 
            int num_orgasms = StorageUtil.GetIntValue(actors[j],actor_num_orgasms_key, 0)
            if num_orgasms < 1
                if orgasm_expected.length > j && orgasm_expected[j] == 1
                    after += actors[j].GetDisplayName()+" was denied an orgasm. "
                    target = actors[j]
                    orgasm_denied = true
                endif
            elseif num_orgasms < 2
                after += actors[j].GetDisplayName()+"'s body glows in post orgasm. "
            else 
                after += actors[j].GetDisplayName()+"'s body is recovering from "+num_orgasms+" orgasms. "
            endif 
            j -= 1 
        endwhile ;
        if target != None
            narration += " "+after
        endif 
    endif 

    if target == None 
        if actors.length > 2 && actors[0] != actors[1]
            target = actors[1]
        endif
    elseif target == actors[0] 
        if actors.length > 2 && actors[0] != actors[1]
            target = actors[1]
        else 
            target = None
        endif 
    endif 
    
    if orgasm_denied
        DirectNarration_Optional(narration, actors[0], target)
    else
        RegisterEvent("sexlab_end", narration, target)
    endif 
    thread_started[ThreadID] = False 

    sslThreadSlots ThreadSlots = Game.GetFormFromFile(0xD62, "SexLab.esm") as sslThreadSlots
    if ThreadSlots == None
        Trace("[SkyrimNet_SexLab] Get_Threads: ThreadSlots is None", true)
        return
    endif
    sslThreadController[] threads = ThreadSlots.Threads

    i = threads.length - 1 
    bool found = false
    while 0 <= i && !found
        String s = (threads[i] as sslThreadModel).GetState()
        if s == "animating" || s == "prepare"
            found = true
        endif 
        i -= 1
    endwhile
    if found
        active_sex = true
    else 
        active_sex = false
    endif

    thread_style[thread.tid] = STYLE_NORMALLY

endEvent

; Function AllowedDeniedOnlyIncrease(Actor[] actors, sslThreadController thread, String status)
    ; if !MiscUtil.FileExists("Data/SexLabAroused.esm") 
        ; return
    ; endif
    ; Store orgasm denied actor's arousal level before sex, It is not allowed to lower 
    ;q = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as Quest
    ;SkyrimNet_SexLab_main main = q as SkyrimNet_SexLab_Main
    ;SkyrimNet_SexLab_Stages stages_lib = q as SkyrimNet_SexLab_Stages

    ; int[] orgasm_denied = new int [1] ; stages.GetOrgasmDenied(thread)
    ; int satisifcation_idx = slaInternalModules.RegisterStaticEffect("Orgasm")
; 
    ; int i = orgasm_denied.length - 1
    ; while 0 <= i    
        ; float sat_value = slaInternalModules.GetStaticEffectValue(actors[i], satisifcation_idx)
        ; if orgasm_denied[i] == 1
            ; if status == "start"
                ; StorageUtil.SetFloatValue(actors[i], storage_arousal_key, sat_value)
            ; else
                ; float stored_value = StorageUtil.GetFloatValue(actors[i], storage_arousal_key)
                ; if stored_value < sat_value
                    ; StorageUtil.SetFloatValue(actors[i], storage_arousal_key, sat_value)
                ; elseif stored_value > sat_value
                    ; slaInternalModules.SetStaticArousalValue(actors[i], satisifcation_idx, stored_value)
                    ; Trace("AllowedDeniedOnlyIncrease",actors[i].GetDisplayName()+" orgasm denied, so erasing orgasm satisifaction "+sat_value+" -> "+stored_value)
                ; endif 
            ; endif 
        ; endif 
        ; sat_value = slaInternalModules.GetStaticEffectValue(actors[i], satisifcation_idx)
        ; i -= 1
    ; endwhile
; EndFunction

; ----------------------------------------------------------------------------------------------------
; Orgasm Event Functions 
; This function is not called when SLSO.esp is installed, as it has its own orgasm handling
; ----------------------------------------------------------------------------------------------------
Event Orgasm_Combined(int ThreadID, bool HasPlayer)
    if SexLab == None
        Trace("Orgasm_Combined","SexLab is None")
        return  
    endif
    sslThreadController thread = SexLab.GetController(ThreadID)
    Actor[] actors = thread.Positions

    ;Quest q = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as Quest
    ;SkyrimNet_SexLab_main main = q as SkyrimNet_SexLab_Main
    ;SkyrimNet_SexLab_Stages stages_lib = q as SkyrimNet_SexLab_Stages
    int[] orgasm_expected = stages.GetOrgasmExpected(thread)
    bool someone_ejaculated = False 
    int i = actors.length - 1
    String narration = "" 
    Trace("Orgasm_Combined","ThreadID:"+threadID+" HasPlayer:"+HasPlayer+" orgasm_expected:"+orgasm_expected)
    while 0 <= i
        String name = actors[i].GetDisplayName()
        int gender = actors[i].GetLeveledActorBase().GetSex() ; actorLib.GetGender(actors[i])
        int gender_sexlab = sexlab.GetGender(actors[i]) 
        bool has_penis = gender != 1 || (gender_sexlab != 1 && gender_sexlab != 3)
        if IsDOMSlave(actors[i])
            if orgasm_expected[i] == 1
                int num_orgasms = StorageUtil.GetIntValue(actors[i], actor_num_orgasms_key, 0)
                if num_orgasms > 0 
                    if has_penis
                        someone_ejaculated = True 
                    endif 
                else 
                    DOM_Actor slave = GetDOMSlave("Orgasm_Combined", actors[i])
                    if slave != None 
                        if slave.mind.is_aroused_for > 0
                            narration += name+" was denied an orgasm. "
                        endif 
                    endif 
                endif 
            endif 
            Trace("Orgasm_Combined",i+" "+name+" | someone_ejaculated: "+someone_ejaculated+" | DOMSlave:true | narration: "+narration)
        else
            if orgasm_expected[i] == 1
                narration += name+" orgasmed. "
                if has_penis
                    someone_ejaculated = True
                endif
            endif 
        endif 
        Trace("Orgasm_Combined",i+" "+name+" | someone_ejaculated: "+someone_ejaculated+" | narration: "+narration)
        i -= 1
    endwhile

    ; Generate cum message 
    i = actors.length - 1
    while 0 <= i 
        if someone_ejaculated
            narration += AddCum(thread, i, actors[i], actors[i].GetDisplayName())
        endif 
        Trace("Orgasm_Combined",i+" "+actors[i].GetDisplayName()+"| adding cum | narration: "+narration)
        i -= 1 
    endwhile 

    if HasPlayer
        DirectNarration(narration, actors[0], None)
    else
        DirectNarration_Optional("sexlab_orgasm", narration, actors[0], None)
    endif
EndEvent 

; Used for SLSO.esp orgasm handling
Event Orgasm_Individual(form akActorForm, int FullEnjoyment, int num_orgasms)

    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    if !config.SeparateOrgasms 
        return 
    endif 

    Actor akActor = akActorForm as Actor
    if akActor == None 
        Trace("Orgasm_Individual","akActor is None")
        return 
    endif 
    if IsDomSlave(akActor)
        return
    endif 

    Orgasm_Individual_Helper(akActor, FullEnjoyment, num_orgasms, akActor.GetDisplayName()+" orgasmed.")
EndEvent

Function Orgasm_Individual_Helper(Actor akActor, int FullEnjoyment, int num_orgasms, String msg, bool require_narration = false)
    Trace("Orgasm_Individual_Helper","akActor:"+akActor.GetDisplayName()+" FullEnjoyment:"+FullEnjoyment+" num_orgasms:"+num_orgasms)

    StorageUtil.SetIntValue(akActor, actor_num_orgasms_key, num_orgasms)

    int gender = sexlab.GetGender(akActor) 
    bool male = gender == 0 || gender == 2
    sslThreadController thread = GetThread(akActor)
    bool has_player = false 
    Actor cum_catcher = None
    String cum_catcher_name = "(None)"
    if thread != None && male 
        has_player = thread.HasPlayer() 
        ; Generate the orgasm message
        Actor[] actors = thread.Positions
        int last = actors.length - 1 
        int i = 0
        while cum_catcher == None && i <= last
            if actors[i] != akActor
                cum_catcher = actors[i]
                cum_catcher_name = cum_catcher.GetDisplayName()
                msg += AddCum(thread, i, cum_catcher, cum_catcher_name)
            endif 
            i += 1 
        endwhile 
    endif 

    bool has_thread = thread != None
    Trace("Orgasm_Individual","has_player:"+has_player+" male:"+male+" cum_catcher:"+cum_catcher_name+" msg:"+msg)

    DirectNarration(msg, akActor, cum_catcher)
;    if has_player || require_narration
;        DirectNarration(msg, akActor, cum_catcher)
;    else    
;        DirectNarration_Optional("sexlab_orgasm", msg, akActor, cum_catcher)
;    endif 
EndFunction

;----------------------------------------------------
; Add Cum
;----------------------------------------------------
String Function AddCum(sslThreadController thread, int position, Actor akActor, String name)
    ; Add cum overlay 
    sslBaseAnimation anim = thread.Animation
    int CumId = anim.GetCumId(position, thread.stage)

    ; -1 - no gender 
    ;  0 - Male (also the default values if the actor is not existing)
    ;  1 - Female
    int gender = akActor.GetLeveledActorBase().GetSex()
    ; 0 - male
    ; 1 - female 
    ; 2 - male creature 
    ; 3 - female creature 
    int gender_sexlab = sexlab.GetGender(akActor)
    bool has_pussy = gender == 1 || gender_sexlab == 1 || gender_sexlab == 3
    String genital = "" 
    if has_pussy
        genital = "pussy"
    else 
        genital = "penis"
    endif 

    String places = "" 
    if cumId > 0
        if cumId == sslObjectFactory.vaginal()
            places = genital
        elseif cumId == sslObjectFactory.oral()
            places = "mouth"
        elseif cumId == sslObjectFactory.anal()
            places = "ass"
        elseif cumId == sslObjectFactory.VaginalOral()
            if has_pussy
                places = genital+" and mouth"
            else
                places = "mouth"
            endif 
        elseif cumId == sslObjectFactory.VaginalAnal()
            if has_pussy
                places = genital+" and ass"
            else
                places = "mouth"
            endif 
        elseif cumId == sslObjectFactory.OralAnal()
            places = "mouth and ass"
        elseif cumId == sslObjectFactory.VaginalOralAnal()
            if has_pussy
                places = "mouth and ass"
            else
                places = genital+", mouth, and ass"
            endif 
        endif
    endif 

    if places != ""
        return name+"'s "+places+" is dripping with warm sticky cum. "
    endif 
    return "" 
EndFunction  

; Increases the 
Bool Function IsDOMSlave(Actor akActor)
    if dom_main_found
        return SkyrimNet_DOM_Utils.IsDOMSlave(akActor)
    endif 
    return False 
EndFunction

DOM_Actor Function GetDOMSlave(String func, Actor akActor, String file = "SkyrimNet_SexLab_Main")
    if dom_main_found
        return SkyrimNet_DOM_Utils.GetSlave(file, func, akActor)
    endif 
    return None
EndFunction

Function DOMSlave_Orgasmed(Actor akActor, String msg)
    Trace("DomSlave_Orgasmed",akActor.GetDisplayName())
    int num_orgasms = StorageUtil.GetIntValue(akActor,actor_num_orgasms_key, 0)
    Orgasm_Individual_Helper(akActor, 100, num_orgasms+1, msg, true)
EndFunction

;----------------------------------------------------
; Parses the tags
;----------------------------------------------------
String Function Thread_Narration(sslThreadController thread, String status)
    ; Get the thread that triggered this event via the thread id
    sslBaseAnimation anim = thread.Animation
    ; Get our list of actors that were in this animation thread.
    Actor[] actors = thread.Positions

    if actors.length == 1 
        if status == "start"
            return actors[0].GetDisplayName()+" starts masturbating."
        elseif status == "are"
            return actors[0].GetDisplayName()+" is masturbating."
        else
            return actors[0].GetDisplayName()+" stops masturbating."
        endif 
    else
        int num_victims = 0
        int k = actors.length - 1
        while 0 <= k 
            if thread.IsVictim(actors[k])
                num_victims += 1   
            endif 
            k -= 1
        endwhile

        if num_victims == 0
            String actors_str = ActorsToString(actors)
            int style = thread_style[thread.tid] 
            String style_str = "having a sexual experience." 
            if style == STYLE_FORCEFULLY 
                style_str = "having a forcefully sexual experience."
            elseif style == STYLE_GENTLY
                style_str = "having a gently making love experience."
            endif 

            if status == "start" 
                return actors_str+" start "+style_str
            elseif status == "are"
                return actors_str+" are "+style_str
            else 
                return actors_str+" stop "+style_str 
            endif 
        else
            Actor[] victims = PapyrusUtil.ActorArray(num_victims)
            Actor[] aggressors = PapyrusUtil.ActorArray(actors.length - num_victims)
            int v = 0
            int a = 0 
            k = actors.length - 1
            while 0 <= k 
                if thread.IsVictim(actors[k])
                    victims[v] = actors[k]
                    v += 1
                else 
                    aggressors[a] = actors[k]
                    a += 1
                endif 
                k -= 1
            endwhile
            String victims_str = ActorsToString(victims)
            String aggressors_str = ActorsToString(aggressors)

            int style = thread_style[thread.tid] 
            String style_str = "" 
            if style == STYLE_FORCEFULLY 
                style_str = "forcefully "
            elseif style == STYLE_GENTLY
                style_str = "gently "
            endif 

            if status == "start"
                return aggressors_str+" starts "+style_str+"raping "+victims_str+"."
            elseif status == "are"
                return aggressors_str+" is "+style_str+"raping "+victims_str+"."
            else 
                return aggressors_str+" stops "+style_str+"raping "+victims_str+"."   
            endif 
        endif 

    endif
EndFunction 
String Function ActorsToString(Actor[] actors) global
    String names = ""
    int k = 0
    int count = actors.length
    while k < count 
        if k > 0
            if count > 2 && k > 0
                names += ", "
            endif
            if k == count - 1 
                names += " and "
            endif
        endif
        names += actors[k].GetDisplayName()
        k += 1
    endwhile 
    return names 
endFunction

String Function ActorsToJson(Actor[] actors) global
    String json = "["
    int i = 0
    int count = actors.length
    while i < count 
        if i > 0
            json += ", "
        endif 
        json += "\""+actors[i].GetDisplayName()+"\""
        i += 1
    endwhile 
    json += "]"
    return json 
EndFunction 

;----------------------------------------------------
; Yes No dialogue chooice for the player 
;----------------------------------------------------

; Allows the user to choose to accept the sex act choosen by the LLM 
; The value will between 
; 1 Yes with the editor 
; 2 Yes, but no tag editor 
; 3 No (silent), refused, but don't tell the LLM 
; 4 NO, tell the LLM 
int function YesNoSexDialog(Actor[] actors, Actor[] victims, Actor player, String type)

    String[] buttons = new String[4]
    buttons[BUTTON_YES] = "Yes "
    buttons[BUTTON_YES_RANDOM] = "Yes (Random)"
    buttons[BUTTON_NO_SILENT] = "No (Silent)"
    buttons[BUTTON_NO] = "No "

    String player_name = player.GetDisplayName()

    String names = "" 
    int i = 0
    int count = actors.length 
    while i < count 
        if actors[i] != player
            if count > 2
                if names != ""
                    names += ", "
                endif 
            endif 
            names += actors[i].GetDisplayName() 
        endif 
        i += 1 
    endwhile 

    String question = "Would you like to have sex with "+names+"?"
    Trace("YesNoSexDialog","question: "+question)
;    if rape
;        if domActor == player
;            question = "Would like to rape "+npc_name+"?"
;        else
;            question = "Would like to be raped by "+npc_name+"?"
;        endif 
;    elseif type == "kissing"
;        question = "Would like to kissing "+npc_name+"?"
;    else
;        question = "Would like to have sex "+npc_name+"?"
;    endif 
    
    int button = SkyMessage.ShowArray(question, buttons, getIndex = true) as int  
    if button == BUTTON_NO || button == BUTTON_NO_SILENT
        if button == BUTTON_NO 
            String msg = player_name+" refuses have sex with "+names
            DirectNarration_Optional("sex refuses", msg, player, actors[0])
        endif 
    endif 
;                DirectNarration_Optional("rape refuses", msg, subActor, domActor)
;            if !rape
;                String msg = "*"+player_name+" refuses "+npc_name+"'s sex request*"
;                DirectNarration_Optional("sex refuses", msg, domActor, subActor)
;            elseif domActor == player 
;                String msg = "*"+player_name+" refuses to rape "+npc_name+".*"
;                DirectNarration_Optional("rape refuses", msg, domActor, subActor)
;            else
;                String msg = "*"+player_name+" refuses "+npc_name+"'s rape attempt.*"
;                DirectNarration_Optional("rape refuses", msg, subActor, domActor)
;            endif
        ;endif
    ;endif 
    return button 
EndFunction

; Selects the style of sex 
; 0 forcefully 
; 1 normally 
; 2 gently 
int Function SexStyleDialog(sslThreadController thread)
    String[] buttons = new String[3] 

    sslBaseAnimation anim = thread.Animation
    Actor[] actors = thread.Positions
    int k = actors.length - 1
    bool rape = False
    while 0 <= k && !rape
        if thread.IsVictim(actors[k])
            rape = True 
        endif 
        k -= 1
    endwhile

    if !rape
        buttons[STYLE_FORCEFULLY] = "Forcefully Fuck"
        buttons[STYLE_NORMALLY] = "Have Sex"
        buttons[STYLE_GENTLY] = "Gently make love"
    else 
        buttons[STYLE_FORCEFULLY] = "Violently Raping"
        buttons[STYLE_NORMALLY] = "Raping"
        buttons[STYLE_GENTLY] = "Gently Raping"
    endif 
    String msg = Thread_Narration(thread, "are")+"\nChange style to:"
    int style = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int 
    thread_style[thread.tid] = style 
    return style
EndFunction

; This function returns the list of animations matching the requested animations
; If no animations were selected, it will return an array with a single None value `[None]`
; 
;   anims = AnmisDialog(sexlab. actors, tag) 
;   if anims.length > 0 && anims[0] != None 
;        thread.SetAnimations(anims)
;   endif 
;
sslBaseAnimation[] Function GetAnimsDialog(SexLabFramework sexlab, Actor[] actors, String tag)
    Trace("GetAnimsDialog","actor.lengths: "+actors.length+" tag:"+tag)

    Actor player = Game.GetPlayer() 

    int i = 0
    int count = actors.Length
    String names = ""
    bool includes_player = False 
    while i < count
        if actors[i] == player 
            includes_player = True 
        endif 
        if names != ""
            names += "+" 
        endif
        names += actors[i].GetDisplayName()
        i += 1 
    endwhile
    names += " | "

    ; Check if enabled by MCM 
    sslBaseAnimation[] empty = new sslBaseAnimation[1]
    empty[0] = None 

    if (includes_player && !sex_edit_tags_player) || (!includes_player && !sex_edit_tags_nonplayer)
        return empty 
    endif 

    ; Current set of tags
    String[] tags = new String[10]
    int count_max = 10
    int next = 0
    if tag != ""
        tags[next] = tag
        next += 1
    endif 

    ; the order of the groups 
    int group_tags = JMap.getObj(group_info,"group_tags",0)
    if group_tags == 0 
        Trace("AnimsDialog", "group_tags not found in group_tags.json")
        return None
    endif 

    int groups = JMap.getObj(group_tags,"groups",0)
    if groups == 0
        groups = JMap.allKeys(group_tags)
    endif 
    count = JArray.count(groups)

    JValue.retain(groups)
    uilistmenu listMenu = uiextensions.GetMenu("UIListMenu") AS uilistmenu
    while True
        bool finished = false
        String tags_str= ""
        while next < count_max && !finished
            listMenu.ResetMenu()

            ; build the current tags
            tags_str = "" 
            i = 0
            while i < next
                if i > 0 
                    tags_str += ","
                endif 
                tags_str += tags[i]
                i += 1
            endwhile 
            ; Use the current set of tags 
            String use_tags = names + " tags: "+tags_str
            listMenu.AddEntryItem(use_tags)

            ; Remove one tag 
            if 0 < next 
                listMenu.AddEntryItem("<remove")
            endif 

            ; Add groups
            i =  0
            while i < count
                String group = JArray.getStr(groups,i)
                listMenu.AddEntryItem(group)
                i += 1
            endwhile

            ; add the actions 
            ;ListAddTags(listMenu, group_tags, "actions>") 

            ; just give up
            listMenu.AddEntryItem("<cancel>")

            listMenu.OpenMenu()
            String button =  listmenu.GetResultString()
            if JMap.hasKey(group_tags, button)
                button = GroupDialog(group_tags, button)
            endif 

            if button == "<cancel>"
                return empty
            elseif button == "<remove"
                next -= 1
            elseif button == use_tags
                finished = true
            elseif button != "-continue-"
                tags[next] = button 
                next += 1
            endif 
        endwhile 
        sslBaseAnimation[] anims =  SexLab.GetAnimationsByTags(actors.length, tags_str, "", true)
        if anims.length > 0
            JValue.release(groups)
            return anims 
        else
            Trace("AnimsDialog","No animations found for: "+tags_str)
            Debug.Notification("No animations found for: "+tags_str)
        endif 
    endwhile 
    JValue.release(groups)
    return empty
EndFunction

Function ListAddTags(uilistmenu listMenu, int group_tags, String group) global
    int tags = JMap.getObj(group_tags, group, 0)
    if tags != 0 
        int i = 0
        int count = JArray.count(tags)
        while i < count
            String tag = JArray.getStr(tags, i, "")
            if tag != ""
                listMenu.AddEntryItem(tag)
            endif
            i += 1
        endwhile 
    endif 
EndFunction

String Function GroupDialog(int group_tags, String group)  global
    uilistmenu listMenu = uiextensions.GetMenu("UIListMenu") AS uilistmenu
    listMenu.ResetMenu()
    listMenu.AddEntryItem("<back")
    ListAddTags(listMenu, group_tags, group) 
    listMenu.OpenMenu()
    String button =  listmenu.GetResultString()
    if button == "<back"
        button = "-continue-"
    endif 
    return button
EndFunction