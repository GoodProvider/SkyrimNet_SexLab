curl -L https://github.com/Mutagen-Modding/Spriggit/releases/latest/download/SpriggitCLI.zip -o SpriggitCLI.zip
if exist "SpriggitCLI\" rd /q /s "SpriggitCLI"
mkdir SpriggitCLI
tar -xf SpriggitCLI.zip -C SpriggitCLI