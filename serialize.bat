@echo off
rem --- This script serializes the specified plugin using Spriggit CLI.
setlocal EnableDelayedExpansion

rem --- Set this to your skyrim install dir if search doesnt work
set SKYRIM_INSTALL_PATH="C:\Skyrim\dev\skyrim\"

if not defined SKYRIM_INSTALL_PATH (
    rem --- Find Skyrim Special Edition (SSE) directory ---
    for /f "tokens=3,*" %%A in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Bethesda Softworks\Skyrim Special Edition" /v "Installed Path" 2^>nul') do (
        if "%%A"=="REG_SZ" (
            set "SKYRIM_INSTALL_PATH=%%B"
        )
    )
)

rem --- Check if found and display the path ---
if defined SKYRIM_INSTALL_PATH (
    echo Skyrim Special Edition installation path: %SKYRIM_INSTALL_PATH%
) else (
    echo Skyrim Special Edition installation not found in the registry.
    goto :EOF
)

if not exist "SpriggitCLI\" (
    echo Downloading Spriggit CLI...
    call updateSpriggit.bat
)

rem --- Cleaned command line below ---
"SpriggitCLI\Spriggit.CLI.exe" convert-from-plugin --InputPath "SkyrimNet_Sexlab.esp" --OutputPath "Spriggit\SkyrimNet_Sexlab" --GameRelease SkyrimSE -p Spriggit.Json -v 0.38.6

:EOF
pause
endlocal