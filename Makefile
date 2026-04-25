VERSION=0.26.5
NAM0=SkyrimNet_SexLab

RELEASE_FILE=versions/SkyrimNet_SexLab ${VERSION}.zip

ANIM_SRC= C:\Skyrim\dev\overwrite\SKSE\Plugins\SkyrimNet_SexLab\animations\_local_
ANIM_DST= SKSE\Plugins\SkyrimNet_SexLab\animations\GoodProvider

swap_headers:
	if exist swapped_source ( \
		rmdir /S /Q Scripts && \
		mkdir Scripts && \
		move swapped_source Scripts\Source && \
		c:\Users\bhuff\.vscode\extensions\joelday.papyrus-lang-vscode-2024.578.1412\pyro\pyro.exe --input-path skyrimse.ppj --game-path C:\Skyrim\dev\skyrim \
	) else ( \
		move Scripts\Source swapped_source && \
		mkdir Scripts\Source && \
		uv run python_scripts/headers_strip_psc.py --source swapped_source --destination Scripts\Source \
	)


merge:
	uv run ./python_scripts/merge_animations.py -s ${ANIM_SRC} -d ${ANIM_DST}
	git add ${ANIM_DST}/*
	git commit ${ANIM_DST}

update: 
	updateSpriggit.bat 
	serialize.bat 

dd: 
	cd headers
	git clone https://github.com/IHateMyKite/PapyrusSourcesDD

release: 
	python3 ./python_scripts/fomod-info.py -v ${VERSION} -n '${NAME}' -o fomod/info.xml fomod-source/info.xml
	python3 ./python_scripts/info.py -v ${VERSION} -n '${NAME}' -o SKSE/Plugins/SkyrimNet_SexLab/info.json
	if exist '${RELEASE_file}' rm /Q /S '${RELEASE_FILE}'
	7z -r a '${RELEASE_FILE}' fomod \
	    Scripts \
		SkyrimNet_SexLab.esp \
		fomod/info.json \
		SKSE

group_tags:
	python3 ./python_scripts/group-tags.py animations > SkyrimNet_SexLab/group_tags.json
