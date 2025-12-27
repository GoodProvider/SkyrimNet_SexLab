VERSION=0.23.0
NAM0=SkyrimNet_SexLab

RELEASE_FILE=versions/SkyrimNet_SexLab ${VERSION}.zip

ANIM_SRC= C:\Skyrim\dev\overwrite\SKSE\Plugins\SkyrimNet_SexLab\animations\_local_
ANIM_DST= SKSE\Plugins\SkyrimNet_SexLab\animations\GoodProvider

merge:
	python3 ./python_scripts/merge_animations.py -s ${ANIM_SRC} -d ${ANIM_DST}

update: 
	updateSpriggit.bat 
	serialize.bat 

release: 
	python3 ./python_scripts/fomod-info.py -v ${VERSION} -n '${NAME}' -o fomod/info.xml fomod-source/info.xml
	python3 ./python_scripts/info.py -v ${VERSION} -n '${NAME}' -o SkyrimNet_SexLab/info.json
	if exist '${RELEASE_file}' rm /Q /S '${RELEASE_FILE}'
	7z -r a '${RELEASE_FILE}' fomod \
	    Scripts \
		README.md \
		SkyrimNet_SexLab.esp \
		fomod/info.json \
		SkyrimNet_SexLab/info.json \
		SkyrimNet_SexLab/group_tags.json \
		SkyrimNet_SexLab/race_to_speech.json \
		SkyrimNet_SexLab/animations \
		SKSE/Plugins/SkyrimNet

group_tags:
	python3 ./python_scripts/group-tags.py animations > SkyrimNet_SexLab/group_tags.json
