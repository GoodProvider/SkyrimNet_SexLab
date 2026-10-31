vcpkg_check_linkage(ONLY_STATIC_LIBRARY)


# MinLL/CommonLibVR: our MIT continuation of CommonLibSSE NG, branched from v4.39.3 (the last MIT release of
# alandtse/CommonLibVR; upstream is GPL-3.0 from v5.0.0, which is not compatible with the Skyrim EULA). 4.39.5 adds
# Skyrim SE 1.7.99 / 1.7.104 support derived from the binaries and address library files. Pinned by commit SHA;
# SHA512 is of https://github.com/MinLL/CommonLibVR/archive/<REF>.tar.gz.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO MinLL/CommonLibVR
    REF 550cc4fb9114649dcf526d1f3d73d710c5d7003b
    SHA512 a053d852b682d597acc9e7684740ab95f212e79542265a3e379ff0132bb333592051ddaa2ffc81b1f85fdbda080afe360f5dc7a54d15d1aa7982a98865ce7243
    HEAD_REF ng
)
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH2
    REPO ValveSoftware/openvr
    REF 60eb187801956ad277f1cae6680e3a410ee0873b
    SHA512 bb85b4705e7095ac65df9969112b2df8930cee7917cc5f14231c5a0ffeed7a73ffa60727fd32f8786a403656f95a3ec0f80bf3ceabc5b8ede964aefb920bc718
    HEAD_REF master
)

file(GLOB OPENVR_FILES "${SOURCE_PATH2}/*")

file(COPY ${OPENVR_FILES} DESTINATION "${SOURCE_PATH}/extern/openvr")

vcpkg_configure_cmake(
    SOURCE_PATH "${SOURCE_PATH}"
    PREFER_NINJA
    OPTIONS -DBUILD_TESTS=off -DSKSE_SUPPORT_XBYAK=off
)

vcpkg_install_cmake()

# Fix up CMake config files - CommonLibVR installs as CommonLibSSE
# Rename to CommonLibSSE to match the port name for find_package()
vcpkg_cmake_config_fixup(PACKAGE_NAME CommonLibSSE CONFIG_PATH lib/cmake/CommonLibSSE)

file(INSTALL "${SOURCE_PATH2}/headers/openvr.h" DESTINATION ${CURRENT_PACKAGES_DIR}/include)
file(INSTALL "${SOURCE_PATH}/cmake/CommonLibSSE.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/CommonLibSSE")

# Install openvr_api.lib so its path in the exported targets file is relocatable
file(INSTALL "${SOURCE_PATH2}/lib/win64/openvr_api.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")

# Patch the absolute buildtrees path to openvr_api.lib that CMake bakes into the exported targets
set(_openvr_repl [[:${_IMPORT_PREFIX}/lib/openvr_api.lib]])
file(READ "${CURRENT_PACKAGES_DIR}/share/CommonLibSSE/CommonLibSSE-targets.cmake" _targets)
string(REGEX REPLACE
    ":[A-Za-z]:[^;\"<>]*/openvr_api\\.lib"
    "${_openvr_repl}"
    _targets "${_targets}")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/CommonLibSSE/CommonLibSSE-targets.cmake" "${_targets}")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
