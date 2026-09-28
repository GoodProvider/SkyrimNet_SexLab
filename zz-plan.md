if speaker == None 
    if num_actors == 1 
      sender = actors[0]
    else 
      sender = actors[1] 
    endif 
endif 

<goal> fix speaking_modifiers should be ["_pain_","_pleasure_"], and Never contain "" </goal> 
<log>
[07/12/2026 - 09:05:16AM] [SkyrimNet_SexLab_Scene.SetPosition] sid:0 ---- start index:0 akActor:Skadi no_orgasm:1 speaking_modifiers:_pain_,_gagged_
[07/12/2026 - 09:05:17AM] [SkyrimNet_SexLab_Scene.SetPosition] sid:0 end index:0 name: Skadi no_orgasm: 1 speaking_modifiers: ["", ""]
</log> 

the tags and it's list should be aligned top of the cell with range rangetextfield. they should wrap around, until finally wrapping under rang rangetextfield. 
```
range rangetextfield tags: hugm holding, standing, cuddling, 
foreplay, leadin, sfw
```

"AP skull fuck" inferrred as orgasm: speaking:, . should be orgasm:,1 speaking:,pleasure from tags: blowjob, oral

AnimationDB inference still not working
| name  | tags | current | should be | 
| Arrok Forkplay | oral | o:,1 speaking:, | o:1,1 speaking:,pleasure | 
| Arrok HugFuck | vaginal | o:,1 speaking:, | o:1,1 speaking:pleasure,pleasure | 
| Arrok Missionary | vaginal | o:,1 speaking:, | o:1,1 speaking:pleasure,pleasure | 
| billy lesbian 69 holding | 69 | o:1,1 speaking:, | o:1,1 speaking:pleasure,pleasure | 

When inferring orgasm and speaking. orgasm and pleasure always go together. 
Manual might be different. 
