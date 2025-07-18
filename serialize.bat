@echo off
rem --- This script serializes the specified plugin using Spriggit CLI.
dealyed expansion enabled
setlocal EnableDelayedExpansion

rem --- Set this to your skyrim install dir if search doesnt work
set SKYRIM_INSTALL_PATH=

if not defined SKYRIM_INSTALL_PATH (
    rem --- Find Skyrim Special Edition (SSE) directory ---
    FOR /F "tokens=3,*" %%A IN ('REG QUERY "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Bethesda Softworks\Skyrim Special Edition" /v "Installed Path"') DO (
        IF "%%A"=="REG_SZ" (
            SET SKYRIM_INSTALL_PATH=%%B
        )
    )
)
echo Skyrim Special Edition installation path: %SKYRIM_INSTALL_PATH%

rem --- Check if found and display the path ---
if defined SKYRIM_INSTALL_PATH (
    echo Skyrim Special Edition installation path: %SKYRIM_INSTALL_PATH%
) else (
    echo Skyrim Special Edition installation not found in the registry.
    goto :EOF
)

if not exist "SpriggitCLI\" (
    echo Downloading Spriggit CLI...
    updateSpriggit.bat
)

SpriggitCLI\Spriggit.CLI.exe convert-from-plugin --InputPath "%SKYRIM_INSTALL_PATH%Data\SkyrimNet_Sexlab.esp" --OutputPath "Spriggit\SkyrimNet_Sexlab" --GameRelease SkyrimSE -p Spriggit.Json -v  0.38.6




:EOF
pause
endlocal