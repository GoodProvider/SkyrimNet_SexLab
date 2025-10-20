scriptname SkyrimNet_SexLab_Creatures 
; This is a helper function used to find all the race form ids and store them into a JSON file 



Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Creatures."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction


Function Store_Races() global
    Trace("Store_Races", "Storing Races' formids.", true )

    String creaturesum_esp = "CreatureSummoner.esp"
    Int actorBaseType = 43

    Form[] forms = PO3_SKSEFunctions.GetAllFormsInMod(asModName = creaturesum_esp, aiFormtype = actorBaseType)
    int i = forms.length - 1 
    int races = JMap.object()
    while 0 < i 
        ActorBase base = forms[i] as ActorBase
        Race r = base.GetRace() 
        String race_name = r.GetName() 
        Trace("StoreRaces",race_name)
        if !JMap.hasKey(races, race_name)
            int info = JMap.object() 
            JMap.setStr(info, "name", race_name) 
            JMap.setForm(info, "form", r)
            JMap.setObj(races,race_name,info) 
        endif 
        i -= 1 
    endwhile
    String filename = "Data/SkyrimNet_Sexlab/name_race.json"
    Trace("SkyrimNet_SexLab_Creatures","forms count: "+JMap.count(races)+" writing "+filename)
    JValue.writeToFile(races, filename) 
EndFunction