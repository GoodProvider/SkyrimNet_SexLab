# SkyrimNet_SexLab

Adds SkyrimNet support to SexLab.

# Actions 
- NPC will be able to start sex
  - ability to set a style of sex: forceful, normal, or gentle 
- NPC will be able to dress and undress

# SexLab Animation Descriptions 
- Descriptions of the sex will be added to the prompt
- Ability to create hand crafted description for each animation
- Ability to flag some positions as not being able to get satisifation from the sex animation

# Hot Key
There is an optional hot key, must be enabled in the MCM.  It supports: 
- ability to start a sexual act with an NPC in the crosshairs or between NPCs not in the crosshairs.
- ability to dress/undress the actor under the across hairs.
- If the NPC in the crosshair or player is in a sexlab animation 
  - change the style of sex 
  - add a per-stage description 
  - change if a given actor expects an orgasm 

## Per Stage Description 
When you press the hot key on an actor in sex, one of two thing will happen:
- If the animation's stage already has a description, the description will be presented with the option to replace it. If you choose to edit, it will be the same as the next step
- If the animation's stage does not have a description, a text field will be presented to add it. 
  - After you finish typing, the code will add the actor's names and present the final description to you.  You can accept or reject. If it is empty you most likely used the wrong variable names.

Descriptions you create will be stored in `SkyrimNet_SexLab/animations/\_local\_`with a single file for each animation. Additional stage descriptions will be stored in `animations/(author_name)` as they are shared with me, or people can simple give them to you.  The author's name will be presented when the description is provided, so you know where to edit the files. You can always create new description in \_local\_.

- Once the file exists, you can edit with your favorite text editor if you so choose.
- If no stage descriptions is used, the tag based description will be used. 
- The last stage with a description will be used if none is found.
- descriptions will be used in the order the directories are read, with \_local\_ loaded last.

- We now support inja format for stage descriptions:
  - There will be an array of actors.  If there is a victim, it is normally the first character.
  - If you aren't sure.  Type just the actors needs so you can see which is which.
  - {{sl.actors.0}} is the first actor 
  - {{sl.actors.1}} is the second, etc 
  - {{sl.actors.2}} is the third, etc 

## Orgasm Expected
Some animation do not provide a justification for all actors expecting an orgasm.
It is stored as an array of integers matching the position of the actors in the thread. 
- 0: the actor does not expect an orgasm
- 1: the actor expects an orgrasm 

## Sex Style 
If you have enabled the Tag Editor, you will be presented with the ability to set the style,
This will change how the sex is presented to the LLM:
- Forcefully fucking
- having sex
- gently making love

## Examples 
Examples can be found in the animations/GoodProvider sub directory.

`SkyrimNet_SexLab\animations\_local_\file.json
~~~json
{
    "stage 1": {
        "description":"{{sl.actors.1}} fingers {{sl.actors.0}}.",
        "version": "2.0"
    },
    "orgasm_expected":[1,0]
}
~~~

## Load Order
Please send me any animations you create by zipping your \_local\_ directory and give me an authors name you would like to use.  I will also accept annoymous submissions.

- Send the zip file to me on discord
- email the zipped file to da.good.provider@gmail.com 

**Requirements**
The following and depedancies:
- [Sexlab Framework](https://www.loverslab.com/files/category/228-sexlab-framework-se/)
- [Papyrus MessageBox](https://www.nexusmods.com/skyrimspecialedition/mods/83578)
- [JContainers](https://www.nexusmods.com/skyrimspecialedition/mods/16495)
- [SkyUI SE](https://www.nexusmods.com/skyrimspecialedition/mods/12604)
  [UIExtensions](https://www.nexusmods.com/skyrimspecialedition/mods/17561)
   - [UIExtensions_UITextEntryMenu_with_VR_support](https://github.com/mrowrpurr/UIExtensions_UITextEntryMenu_with_VR_support) (VR users)
- SkyrimNet (Beta7 or later)
   - You must have narration enabled
- SkryimNet_SexLab (this mod) 
 
**Optional**
- [SkyrimNet_Arousal](https://github.com/GoodProvider/SkyrimNet_Arousal) adds arousal to prompt / add arousal actions 
- [OSL Aroused](https://www.nexusmods.com/skyrimspecialedition/mods/65454)
   - Will prevent orgasm from increasing satisfaction for tagged actors for a given animations
- [OstimNet](https://github.com/tetherball88/OStimNet)
  - if install, MCM will allow the user to select which framework will be used by the LLM to start sex.  
        

**Other SkyrimNet NSWF**
- [skyrimNet CumSwallowNeeds](mods/SkyrimNet-CumSwallowNeeds.zip) (Author Token) 
   - [CumSwallowNeeds](https://www.loverslab.com/files/file/29763-cumswallowneedsaddon/)

**Recommendations**
- **Utils**
    -  [SKSE](https://skse.silverlock.org/)
    -  [Address Library for SKSE Plugins](https://www.nexusmods.com/skyrimspecialedition/mods/32444)
    -  [Unofficial Skyrim Special Edition Patch - USSEP](https://www.nexusmods.com/skyrimspecialedition/mods/266)
    -  [PapyrusUtil SE](https://www.nexusmods.com/skyrimspecialedition/mods/13048)
    -  [Powerof three Papyrus Extender](https://www.nexusmods.com/skyrimspecialedition/mods/22854)
    -  [Power of three Tweaks](https://www.nexusmods.com/skyrimspecialedition/mods/51073)
    -  [Alternate Start](https://www.nexusmods.com/skyrimspecialedition/mods/272) (nice, but not needed)
       - [Unofficial Skyrim Sepcial Edition Patch](https://www.nexusmods.com/skyrimspecialedition/mods/51073)
    -  [Stay At the System Page NG](https://www.nexusmods.com/skyrimspecialedition/mods/76927)
    -  [Papyrus MessageBox](https://www.nexusmods.com/skyrimspecialedition/mods/83578)
    -   SkyrimNet 
- **nude body (not required)**
    -   [Caliente's Beautiful Bodies Enhancer -CBBE-](https://www.nexusmods.com/skyrimspecialedition/mods/198) or BHUNP
    -   [The New Gentlemen](https://www.loverslab.com/files/file/5355-schlongs-of-skyrim-se/)
        - [The New Gentlewomen](https://www.nexusmods.com/skyrimspecialedition/mods/105649) futanari support
            - https://www.loverslab.com/files/file/11344-sos-addon-futanari-cbbe-sse/
            - TRX Futanari for New Gentlemen (TRX-Corner on [Vermi Discord](https://discord.gg/vermishub))
            - You will need to add using T.N.G's hotkey after exiting racemenu
            - Change the character's gender to male in SexLab only.
- **SexLab**
    -  [Sexlab Framework](https://www.loverslab.com/files/category/228-sexlab-framework-se/)
    -  [SexLab Tools](https://www.loverslab.com/files/file/10660-sexlab-tools-for-se-patched/) (Allows you to change animations with 'h' hotkey)
- **Animation**
    -  [Pandora](https://www.nexusmods.com/skyrimspecialedition/mods/133232)
    -  Pandora Output (recommended to store Pandora's output)
    -  [XP32 Maximum Skeleton Special Extended (XPMSSE)](https://www.nexusmods.com/skyrimspecialedition/mods/1988)
    -   [SL Animation Loader](https://www.loverslab.com/files/file/5328-sexlab-animation-loader-sse/)
- **animations** (you might be able to get away with less ... )
    -   [Billyy](https://www.loverslab.com/files/file/3999-billyys-slal-animations-2025-1-1/)
- **Devious Devices** 
    - [SkyrimNet DDUNDNG](https://github.com/naitro2010/SkyrimNet_UDNG/releases/download/alpha2/SkyrimNetDDUDNG.zip)
    - [Devious Devices](https://www.loverslab.com/files/file/5878-devious-devices-se/) (and it's requirements)
    - [Papyrus Tweaks NG](https://www.nexusmods.com/skyrimspecialedition/mods/77779)
    - [Devious Devices NG](https://www.loverslab.com/files/file/29779-devious-devices-ng/)
        - [Blind people DAR](https://www.nexusmods.com/skyrimspecialedition/mods/90947)
        - [Bound hands DAR](https://www.nexusmods.com/skyrimspecialedition/mods/89247) (required for next file) 
        - [Bound hands OAR](https://www.nexusmods.com/skyrimspecialedition/mods/143622?tab=files)

