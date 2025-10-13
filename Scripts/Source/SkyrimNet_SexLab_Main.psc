Scriptname SkyrimNet_SexLab_Main extends Quest

import JContainers
import UIExtensions
import SkyrimNet_SexLab_Decorators
import SkyrimNet_SexLab_Actions
import SkyrimNet_SexLab_Stages
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

SkyrimNet_SexLab_Stages Property stages Auto
SexLabFramework Property sexlab Auto 

Quest Property dom_main Auto 
bool Property dom_main_found Auto


string actor_num_orgasms_key = "skyrimnet_sexlab_actor_num_orgasms"
; Stores if SLSO.esp is found
float last_time_direct_narration = 0.0

; OstimNet 
bool ostimnet_found = false 

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

    if MiscUtil.FileExists("Data/SkyrimNet_DOM.esp")
        dom_main = Game.GetFormFromFile(0x800, "SkyrimNet_DOM.esp") as Quest
        dom_main_found = True
    else 
        dom_main = None 
        dom_main_found = False
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
        group_info = JValue.readFromFile("Data/SkyrimNet_Sexlab/group_tags.json")
        JValue.retain(group_info)
    else
        int group_info_new = JValue.readFromFile("Data/SkyrimNet_Sexlab/group_tags.json")
        Jvalue.releaseAndRetain(group_info, group_info_new)
        group_info = group_info_new
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
Function SetThreadStyle(int thread_id, int style) 
    thread_style[thread_id] = style 
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
    RegisterForModEvent("HookOrgasmStart", "Orgasm_Combined")

EndFunction 

event AnimationStart(int ThreadID, bool HasPlayer)
    if SexLab == None
        return  
    endif
    sslThreadController thread = SexLab.GetController(ThreadID)
    Actor[] actors = thread.Positions

    if (HasPlayer && sex_edit_tags_player) || (!HasPlayer && sex_edit_tags_nonplayer)
        SexStyleDialog(thread) 
    endif 

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
            Trace("AnimationStart","actor:"+actors[j].GetDisplayName()+" reset num orgasm")
            StorageUtil.SetIntValue(actors[j], actor_num_orgasms_key, 0)
            j -= 1 
        endwhile 
    endif 

    thread_started[thread.tid] = False 
endEvent

Event StageStart(int ThreadID, bool HasPlayer)
    if SexLab == None
        return  
    endif

    if !thread_started[ThreadID]
        active_sex = true
        Sex_Event(ThreadID, "start", HasPlayer )
        thread_started[ThreadID] = True
    endif 

    sslThreadController thread = SexLab.GetController(ThreadID)
    AllowedDeniedOnlyIncrease(thread.positions, thread, "stage") 

    Actor[] actors = thread.Positions

    Actor sender = actors[0] 
    Actor reciever = None 
    if actors.length > 1 
        reciever = actors[1] 
    endif 

    String narration = Thread_Narration(thread, "are")
    DirectNarration("sexlab_stage_change", narration, sender, reciever, True)

    ; This provides the animation updates below this point
    if !stages.IsThreadTracking(ThreadID)
        return
    endif 
    bool[] desc_denied = stages.HasDescriptionOrgasmDenied(thread)
    String desc = "" 
    if desc_denied[0]
        desc = "has description"
    endif
    if desc_denied[1]
        if desc != ""
            desc += " and "
        endif 
        desc += "orgasm denied"        
    endif
    Debug.Notification("stage "+thread.stage+" of "+ thread.animation.StageCount()+" "+desc)

        ; DOM Slaves have thier own orasm system 

    if dom_main != None 
        int k = actors.length - 1
        while 0 <= k 
            DOM_Actor slave = SkyrimNet_DOM_Utils.GetSlave("SkyrimNet_SexLab_Main","Start_Sex",actors[k],true,true)
            Debug.Notification("slave:"+slave)
            if (dom_main as SkyrimNet_DOM_Main).IsDomSlave(actors[k]) 
                Debug.Notification(actors[k].GetDisplayName()+" denied")
            else
                Debug.Notification(actors[k].GetDisplayName()+" allowed")
            endif 
            k -= 1 
        endwhile
    endif 

EndEvent

; Used for default orgasm
Event Orgasm_Combined(int ThreadID, bool HasPlayer)
    Trace("OrgasmStart","ThreadID:"+ThreadID+" HasPlayer:"+HasPlayer)
    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    if !config.SeparateOrgasms 
        Orgasm_Event(ThreadID)
    endif 
EndEvent

; Used for SLSO.esp orgasm handling
Event Orgasm_Individual(form akActorForm, int FullEnjoyment, int num_orgasms)

    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    if !config.SeparateOrgasms 
        return 
    endif 

    Actor akActor = akActorForm as Actor
    StorageUtil.SetIntValue(akActor, actor_num_orgasms_key, num_orgasms)
    Trace("Orgasm_Individual","akActor:"+akActor.GetDisplayName()+" FullEnjoyment:"+FullEnjoyment+" num_orgasms:"+num_orgasms)
    if akActor == None 
        return 
    endif 

    sslActorLibrary ActorLib = (SexLab as Quest) as sslActorLibrary
    bool can_ejaculate = Actorlib.GetGender(akActor) != 1
    String msg = ""
    if can_ejaculate
        sslThreadController thread = stages.GetThread(akActor)
        if thread != None 
            Actor[] actors = thread.Positions
            int i = actors.length - 1 
            int position = -1
            while 0 <= i && position == -1
                if actors[i] != akActor  
                    position = i
                endif 
                i -= 1
            endwhile

            if position != -1
                Actor reciever = actors[position]
                msg = Ejaculation(akActor.GetDisplayName(), reciever.GetDisplayName(), position, thread)
                DirectNarration("sexlab_orgasm", msg, akActor, reciever)
            endif 
        endif 
    endif 
    if msg == ""
        msg = akActor.GetDisplayName()+" orgasmed."
        DirectNarration("sexlab_orgasm", msg, akActor, None)
    endif 
EndEvent 

event AnimationEnd(int ThreadID, bool HasPlayer)
    Trace("AnimationEnd","ThreadID:"+ThreadID+" HasPlayer:"+HasPlayer)
    ; String desc = stages.GetStageDescription(SexLab.GetController(ThreadID))
    ; if desc != ""
        ; Actor[] actors = SexLab.GetController(ThreadID).Positions
        ; desc = stages.Description_Add_Actors(s, desc)
        ; Skyrim
    ; endif 
    Sex_Event(ThreadID, "stop", HasPlayer )
    thread_started[ThreadID] = False 

    sslThreadSlots ThreadSlots = Game.GetFormFromFile(0xD62, "SexLab.esm") as sslThreadSlots
    if ThreadSlots == None
        Trace("[SkyrimNet_SexLab] Get_Threads: ThreadSlots is None", true)
        return
    endif
    sslThreadController[] threads = ThreadSlots.Threads

    int i = threads.length - 1 
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
    Trace("AnimationEnd","got to 3")

    sslThreadController thread = SexLab.GetController(ThreadID)
    thread_style[thread.tid] = STYLE_NORMALLY

    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    Actor[] actors = thread.Positions
    Trace("AnimationEnd","checking orgasms for "+ActorsToString(actors))
    if config.SeparateOrgasms
        String after = "" 
        int j = actors.length - 1 
        while 0 <= j 
            int num_orgasms = StorageUtil.GetIntValue(actors[j],actor_num_orgasms_key, 0)
            if num_orgasms < 1
                after += actors[j].GetDisplayName()+" was denied an orgasm "
            elseif num_orgasms < 2
                after += actors[j].GetDisplayName()+"'s body glows in post orgasm. "
            else 
                after += actors[j].GetDisplayName()+"'s body is recovering from "+num_orgasms+" orgasms. "
            endif 
            j -= 1 
        endwhile 
        if after != ""
            DirectNarration("sexlab_orgasm", after, None, None)
            Trace("AnimationEnd",after)
        endif 
    endif 
    Trace("AnimationEnd","got to 4")
endEvent

Function Sex_Event(int ThreadID, String status, Bool HasPlayer )
    if SexLab == None
        return  
    endif
    sslThreadController thread = SexLab.GetController(ThreadID)
    Actor[] actors = thread.Positions

    String narration = Thread_Narration(thread, status)

    ; the Dialog narration is called so that it is stored in the timeline and captured in memories,
    ; and will be responded by t
    String eventType = "sex "+status
    ; narration = "*"+narration+"*"
    if actors.length < 2 || actors[0] == actors[1]
        if status == "start"
            SkyrimNetApi.DirectNarration(narration, actors[0], None)
        else
            ;if actors.length == 1 || actors[0] == actors[1]
                ;SkyrimNetApi.RegisterDialogue(actors[0], "*"+narration+"*")
            ;else
                ;SkyrimNetApi.RegisterDialogueToListener(actors[1], actors[0], "*"+narration+"*")
            ;endif 
            SkyrimNetApi.RegisterEvent(eventType, "*"+narration+"*", actors[0], None)
        endif 
    elseif actors.length == 2
        if status == "start"
            SkyrimNetApi.DirectNarration(narration, actors[1], actors[0])
        else
            SkyrimNetApi.RegisterEvent(eventType, "*"+narration+"*", actors[1], actors[0])
            ;SkyrimNetApi.RegisterDialogueToListener(actors[1], actors[0], "*"+narration+"*")
        endif 
    else
        SkyrimNetApi.RegisterEvent(eventType, narration,None,None)
    endif 

    AllowedDeniedOnlyIncrease(actors, thread, status) 
EndFunction

Function AllowedDeniedOnlyIncrease(Actor[] actors, sslThreadController thread, String status)
    if !MiscUtil.FileExists("Data/SexLabAroused.esm") 
        return
    endif
    ; Store orgasm denied actor's arousal level before sex, It is not allowed to lower 
    ;q = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as Quest
    ;SkyrimNet_SexLab_main main = q as SkyrimNet_SexLab_Main
    ;SkyrimNet_SexLab_Stages stages_lib = q as SkyrimNet_SexLab_Stages
    int[] orgasm_denied = stages.GetOrgasmDenied(thread)
    int satisifcation_idx = slaInternalModules.RegisterStaticEffect("Orgasm")

    int i = orgasm_denied.length - 1
    while 0 <= i    
        float sat_value = slaInternalModules.GetStaticEffectValue(actors[i], satisifcation_idx)
        if orgasm_denied[i] == 1
            if status == "start"
                StorageUtil.SetFloatValue(actors[i], storage_arousal_key, sat_value)
            else
                float stored_value = StorageUtil.GetFloatValue(actors[i], storage_arousal_key)
                if stored_value < sat_value
                    StorageUtil.SetFloatValue(actors[i], storage_arousal_key, sat_value)
                elseif stored_value > sat_value
                    slaInternalModules.SetStaticArousalValue(actors[i], satisifcation_idx, stored_value)
                    Trace("AllowedDeniedOnlyIncrease",actors[i].GetDisplayName()+" orgasm denied, so erasing orgasm satisifaction "+sat_value+" -> "+stored_value)
                endif 
            endif 
        endif 
        sat_value = slaInternalModules.GetStaticEffectValue(actors[i], satisifcation_idx)
        i -= 1
    endwhile
EndFunction

; ----------------------------------------------------------------------------------------------------
; Orgasm Event Functions 
; This function is not called when SLSO.esp is installed, as it has its own orgasm handling
; ----------------------------------------------------------------------------------------------------
Function Orgasm_Event(int ThreadID)
    if SexLab == None
        return  
    endif
    sslActorLibrary ActorLib = (SexLab as Quest) as sslActorLibrary
    
    ; Store orgasm denied actor's arousal level before orgasm, we need to prevent the denied orgasm lower it 

    sslThreadController thread = SexLab.GetController(ThreadID)
    Actor[] actors = thread.Positions

    AllowedDeniedOnlyIncrease(actors, thread, "orgasm") 

    String[] names = new String[2]
    names[0] = actors[0].GetDisplayName()
    if actors.length > 1
        names[1] = actors[1].GetDisplayName()
    endif 
    bool[] can_ejaculate = new Bool[2]
    can_ejaculate[0] = Actorlib.GetGender(actors[0]) != 1
    if actors.length > 1
        can_ejaculate[1] = Actorlib.GetGender(actors[1]) != 1
    endif 

    sslBaseAnimation anim = thread.Animation

    Quest q = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as Quest
    SkyrimNet_SexLab_main main = q as SkyrimNet_SexLab_Main
    SkyrimNet_SexLab_Stages stages_lib = q as SkyrimNet_SexLab_Stages
    int[] orgasm_denied = stages_lib.GetOrgasmDenied(thread)

    int position = 0
    String narration = ""
    while position < actors.length
        int j = (position+1)%(names.length)

        if position < orgasm_denied.length && orgasm_denied[position] == 1
            narration += names[position]+" was denied orgasm. "
        elseif dom_main != None 
            DOM_Actor slave = SkyrimNet_DOM_Utils.GetSlave("SkyrimNet_SexLab_MCM", "Orgasm_Event", actors[position],false,false)
            if slave != None && slave.mind.is_aroused_for > 0 
                narration += names[position]+" frustrared that they are stopping before orgasm."
            endif 
            ; Do nothing, orgasm handled by Dom 
        elseif can_ejaculate[position]

            narration += Ejaculation(names[position], names[j], j, thread)
        else
            narration += names[position]+" orgasmed. "
        endif 
        position += 1
    endwhile
    ;String desc = GetStageDescription(thread)
    ;if desc != ""
    ;    narration = desc+" "+narration
    ;endif 

    SkyrimNetApi.DirectNarration(narration)
EndFunction  

String Function Ejaculation(String sender, String reciever, int position ,sslThreadController thread) 
    sslBaseAnimation anim = thread.Animation
    Bool[] loc = new Bool[4]
    String[] loc_str = new String[4]
    int loc_anal = 0
    int loc_vaginal = 1
    int loc_oral = 2   
    int loc_chest = 3
    loc_str[loc_anal] = "ass"
    loc_str[loc_vaginal] = "pussy"     
    loc_str[loc_oral] = "mouth"
    loc_str[loc_chest] = "chest"

    if anim.HasTag("anal")
        loc[loc_anal] = true
    elseif anim.HasTag("vaginal")
        loc[loc_vaginal] = true    
    elseif anim.HasTag("oral") || anim.HasTag("blowjob") || anim.HasTag("cunnilingus") || anim.HasTag("CumInMouth")
        loc[loc_oral] = true   
    elseif anim.HasTag("boobjob") 
        loc[loc_chest] = true      
    endif 

    int CumId = anim.GetCumId(position, thread.stage)
    if cumId > 0
        if cumId == sslObjectFactory.vaginal()
            loc[loc_vaginal] = true
        elseif cumId == sslObjectFactory.oral()
            loc[loc_oral] = true
        elseif cumId == sslObjectFactory.anal()
            loc[loc_anal] = true
        elseif cumId == sslObjectFactory.VaginalOral()
            loc[loc_vaginal] = true
            loc[loc_oral] = true
        elseif cumId == sslObjectFactory.VaginalAnal()
            loc[loc_vaginal] = true
            loc[loc_anal] = true
        elseif cumId == sslObjectFactory.OralAnal()
            loc[loc_oral] = true
            loc[loc_anal] = true
        elseif cumId == sslObjectFactory.VaginalOralAnal()
            loc[loc_vaginal] = true
            loc[loc_oral] = true
            loc[loc_anal] = true
        endif
    endif 
    String narration = sender+" orgasmed"
    if loc[loc_anal] || loc[loc_vaginal] || loc[loc_oral] || loc[loc_chest]
        narration += ", leaving warm sticky cum dripping from " + reciever +"'s "

        int i = 0
        while i < loc_str.length
            if loc[i]
                narration += loc_str[i]
                if i < loc_str.length - 1
                    narration += ", "
                endif
            endif
            i += 1
        endwhile
    endif 
    narration += ". "
    return narration 
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
int function YesNoSexDialog(String type, Bool rape, Actor domActor, Actor subActor, Actor player)

    if subActor != player && (domActor == None || domActor != player)
        return BUTTON_YES
    endif  

    String[] buttons = new String[4]
    buttons[BUTTON_YES] = "Yes "
    buttons[BUTTON_YES_RANDOM] = "Yes (Random)"
    buttons[BUTTON_NO_SILENT] = "No (Silent)"
    buttons[BUTTON_NO] = "No "

    String player_name = domActor.GetDisplayName()
    String npc_name = subActor.GetDisplayName()

    if subActor == player
        String temp = npc_name 
        npc_name = player_name 
        player_name = npc_name 
    endif
    String question = ""
    if rape
        if domActor == player
            question = "Would like to rape "+npc_name+"?"
        else
            question = "Would like to be raped by "+npc_name+"?"
        endif 
    elseif type == "kissing"
        question = "Would like to kissing "+npc_name+"?"
    else
        question = "Would like to have sex "+npc_name+"?"
    endif 
    
    int button = SkyMessage.ShowArray(question, buttons, getIndex = true) as int  
    if button == BUTTON_NO || button == BUTTON_NO_SILENT
        if button == BUTTON_NO 
            if !rape
                String msg = "*"+player_name+" refuses "+npc_name+"'s sex request*"
                SkyrimNetApi.RegisterEvent("sex refuses", msg, domActor, subActor)
            elseif domActor == player 
                String msg = "*"+player_name+" refuses to rape "+npc_name+".*"
                SkyrimNetApi.RegisterEvent("rape refuses", msg, domActor, subActor)
            else
                String msg = "*"+player_name+" refuses "+npc_name+"'s rape attempt.*"
                SkyrimNetApi.RegisterEvent("rape refuses", msg, subActor, domActor)
            endif
        endif
    endif 
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
sslBaseAnimation[] Function AnimsDialog(SexLabFramework sexlab, Actor[] actors, String tag)

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

    while True
        bool finished = false
        String tags_str= ""
        while next < count_max && !finished

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


            uilistmenu listMenu = uiextensions.GetMenu("UIListMenu") AS uilistmenu
            listMenu.ResetMenu()
            ; Use the current set of tags 
            String use_tags = names + " tags: "+tags_str
            listMenu.AddEntryItem(use_tags)
            ; Remove one tag 
            if 0 < next 
                listMenu.AddEntryItem("<remove")
            endif 

            ; Add groups
            count = JArray.count(groups)
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
            return anims 
        else
            Trace("AnimsDialog","No animations found for: "+tags_str)
            Debug.Notification("No animations found for: "+tags_str)
        endif 
    endwhile 
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

Function DirectNarration(String event_type, String msg, Actor originatorActor=None, Actor targetActor=None, bool optional=False)
    float current_time = Utility.GetCurrentRealTime()
    float delta = current_time - last_time_direct_narration
    String type = "" 
    if last_time_direct_narration == 0.0 || current_time - last_time_direct_narration > 10.0
        SkyrimNetApi.DirectNarration(msg, originatorActor, targetActor)
        type = "directed"
    else 
        if !optional
            SkyrimNetApi.RegisterEvent(event_type, msg, originatorActor, targetActor)
            type = "event"
        else 
            type = "skipped"
        endif 
    endif 
    Trace("DirectNarration","msg:"+msg+" delta:"+delta+" "+type)
    last_time_direct_narration = current_time
EndFunction