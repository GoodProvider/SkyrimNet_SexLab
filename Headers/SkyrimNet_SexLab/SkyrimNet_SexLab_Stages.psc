Scriptname SkyrimNet_SexLab_Stages extends Quest 

import SkyrimNet_SexLab_Main
import StorageUtil

SkyrimNet_SexLab_Actions actions = None 

Bool Property hide_help = false Auto

Actor player = None 

String Property animations_folder = "Data/SKSE/Plugins/SkyrimNet_SexLab/animations" Auto
String Property local_folder =      "" Auto

String VERSION_1_0 = "1.0"
String VERSION_2_0 = "2.0"

String desc_input = "" 

String tracking_db = ""

int tracking_thread_id = 0

String Button_Ok = "Ok"
String Button_Cancel = "Cancel"
String Button_Next = "Next"
String Button_Previous = "Previous"
String Button_Accept = "Accept"
String Button_Rewrite = "Rewrite"
String Button_Retry = "Retry"
String Button_Never_Show_Again = "Never Show Again"
String Button_orgasm_expected = "Orgasm Expected"
String Button_Stop_Tracking = "Stop Tracking"
String Button_Start_Tracking = "Start Tracking"
String Button_Go_Back = "Go Back"
String Button_Done = "Done"

String storage_key = "skyrimnet_sexlab_stages_anim_info"

int anim_info_cache = 0

; Devious Devices
bool devices_found = false 
Keyword Property zad_DeviousBelt Auto

Function Trace(String func, String msg, Bool notification=False) global
EndFunction

Function Setup()
EndFunction

String Function GetStageDescription(sslThreadController thread) global
EndFunction 

String Function Description_Add_Actors(String version, Actor[] actors, String desc)
EndFunction 
; ------------------------------------
; Tracking Function 
; ------------------------------------
Function StartThreadTracking(int thread_id)
EndFunction

Function StopThreadTracking(int thread_id)
EndFunction 

function ToggleThreadTracking(int thread_id)
EndFunction

bool Function IsThreadTracking(int thread_id)
EndFunction

; ------------------------------------
; Edit Description Function 
; Returns True if there was a thread to edit
; ------------------------------------

Function EditDescriptions(sslThreadController thread)
EndFunction 

; ------------------------------------
; Editor Functions 
; ------------------------------------
string Function GetPlayerInput() global
EndFunction

Function EditorDescription(SkyrimNet_SexLab_Main main, sslThreadController thread)
EndFunction

String Function BuildExample(Actor[] actors) 
EndFunction



; ------------------------------------
; Orgasm Expected Functions
; ------------------------------------
int[] Function GetOrgasmExpected(sslThreadController thread) 
    Trace("GetOrgasmExpected","thread: "+thread.tid+" "+thread.animation.name)
    String fname = GetFilename(thread)
    Actor[] actors = thread.Positions
    int anim_info = GetAnim_Info(thread)
    if anim_info == 0
        return Utility.CreateIntArray(actors.length, 0)
    endif 
    int id = 0 
    if JMap.hasKey(anim_info, "orgasm_expected")
        id = JMap.getObj(anim_info, "orgasm_expected")
    endif 

    int count = 0 
    if id != 0 
        count = Jarray.count(id)
    endif 
    if count == actors.length
        int[] orgasm_expected = JArray.asIntArray(id)
        Trace("GetOrgasmExpected","values found in file orgasm_expected: "+orgasm_expected)
        return JArray.asIntArray(id)
    endif 

    if actors.length > 2
        Trace("GetOrgasmExpected","more than 2 actors, all orgasm expected")
        return Utility.CreateIntArray(actors.length, 1)
    endif

    SkyrimNet_SexLab_Main main = (self as Quest) as SkyrimNet_SexLab_Main
    sslActorLibrary actorLib = (main.SexLab as Quest) as sslActorLibrary
    int[] orgasm_expected = Utility.CreateIntArray(actors.length, 1)
    sslBaseAnimation Animation = thread.animation
    Trace("GetOrgasmExpected","tags:"+animation.GetRawTags())

    int i = actors.length - 1
    while 0 <= i 
        ; -1 - no gender 
        ;  0 - Male (also the default values if the actor is not existing)
        ;  1 - Female
        int gender = actors[i].GetLeveledActorBase().GetSex() ; actorLib.GetGender(actors[i])
        int gender_sexlab = main.sexlab.GetGender(actors[i]) 
        bool has_penis = gender != 1 || (gender_sexlab != 1 && gender_sexlab != 3)
        bool has_pussy = gender == 1 || gender_sexlab == 1 || gender_sexlab == 3


        String reason = ""
        if devices_found && actors[i].WornHasKeyword(zad_DeviousBelt)
            orgasm_expected[i] = 0
            reason = "has DD belt"
        elseif Animation.HasTag("Estrus")
            orgasm_expected[i] = 1
            reason = "animation has tag estrus"
        elseif Animation.HasTag("69") || Animation.HasTag("Masturbation")
            orgasm_expected[i] = 1
            reason = "animation has tag 69 or masturbation"
        else
            if i == 0 
                if has_pussy && (Animation.HasTag("Vaginal") || Animation.HasTag("Cunnilingus") || Animation.HasTag("Lesbian") || Animation.HasTag("Fingering") || Animation.HasTag("Dildo"))
                    orgasm_expected[i] = 1 
                    reason = "position 0 with pussy and tag: vaginal, cunnilingus, lesbian, fingering, or dildo"
                elseif Animation.hasTag("Anal") || Animation.HasTag("Fisting")
                    orgasm_expected[i] = 1 
                    reason = "position 0 with tags: anal or fisting)"
                else
                    orgasm_expected[i] = 0
                    reason = "position 0 with out: pussy+tag(vaginal, cunnilingus, lesbian, fingering, dildo) or (anal, fisting)"
                endif 
            else 
                if has_penis && (Animation.HasTag("Vaginal") || Animation.HasTag("Boobjob") || Animation.HasTag("Blowjob") || Animation.HasTag("Handjob") || Animation.HasTag("Footjob") || Animation.HasTag("Oral") || Animation.HasTag("Anal"))
                    orgasm_expected[i] = 1
                    reason = "position 1+ with penis and tags: vaginal, boobjob, blowjob, handjob, footjob, oral, or anal"

                else
                    orgasm_expected[i] = 0
                    reason = "position 1+ without penis+tag(vaginal, boobjob, blowjob, handjob, footjob, oral, anal)"
                endif 
            endif 
        endIf

        String name = actors[i].GetDisplayName()
        bool expected = orgasm_expected[i] == 1 
        ; Trace("GetOrgasmExpected","    "+i+" "+name+" pussy:"+has_pussy+" penis:"+has_penis+" orgasm_expected:"+expected+" reasoning:"+reason)
        i -= 1
    endwhile
    Trace("GetOrgasmExpected","    orgasm_expected: "+orgasm_expected)
    return orgasm_expected
EndFunction

Function SetOrgasmExpected(SkyrimNet_SexLab_Main main, sslThreadController thread)
EndFunction

; ------------------------------------
; Helper functions
; ------------------------------------

bool[] Function GetHasDescriptionOrgasmExpected(sslThreadController thread)
    int anim_info = GetAnim_Info(thread)
    bool[] desc_orgasmExpected = Utility.CreateBoolArray(2, false)
    if anim_info == 0 
        return desc_orgasmExpected
    endif 
    String stage_id = "stage "+thread.stage
    desc_orgasmExpected[0] = JMap.hasKey(anim_info, stage_id)
    int orgasm_expected = JMap.getObj(anim_info, "orgasm_expected")
    if orgasm_expected != 0
        desc_orgasmExpected[1] = true
    endif 
    return desc_orgasmExpected
EndFunction

int Function GetAnim_Info(sslThreadController thread, Bool force_load=False)
EndFunction 

Function UpdateAnimInfo(SkyrimNet_SexLab_Main main, sslThreadController thread, String field, String version, int[] orgasm_expected)
EndFunction 

Function SetAnimCache(sslThreadController thread, int anim_info)
EndFunction 

String Function GetFilename(sslThreadController thread) global
EndFunction 