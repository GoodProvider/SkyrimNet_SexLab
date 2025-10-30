IF exist "dist" (
    rmdir dist /s /q
) ELSE (
    mkdir dist
)

xcopy  fomod dist\fomod\ /S /I
xcopy  Scripts dist\Scripts\ /S /I
xcopy  SKSE dist\SKSE\ /S /I
xcopy  SkyrimNet_SexLab dist\SkyrimNet_SexLab\ /S /I



SpriggitCLI\Spriggit.CLI.exe convert-to-plugin -i "Spriggit\SkyrimNet_Sexlab" -o "dist\SkyrimNet_Sexlab.esp" 
