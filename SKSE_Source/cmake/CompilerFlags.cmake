# CompilerFlags.cmake
# Configures compiler-specific flags and optimizations

# LTO (Link-Time Optimization) via /GL + /LTCG. ON by default for full optimization.
# Disable with -DENABLE_LTO=OFF for faster link times during development.
option(ENABLE_LTO "Enable link-time optimization (/GL + /LTCG)" ON)

# Statically link the C runtime (avoids MSVC redistributable DLLs)
if(MSVC)
    # Add compilation speed optimizations
    # /d2ReducedOptimizeHugeFunctions - Faster optimization for large functions
    string(APPEND CMAKE_CXX_FLAGS " /d2ReducedOptimizeHugeFunctions")

    # Code generation optimizations
    string(APPEND CMAKE_CXX_FLAGS " /Gy") # Function-level linking (enables dead code elimination)
    string(APPEND CMAKE_CXX_FLAGS " /Gw") # Optimize global data (similar to /Gy for globals)
    string(APPEND CMAKE_CXX_FLAGS " /arch:AVX2") # Use AVX2 SIMD instructions
    
    # Strict C++ standard conformance flags
    string(APPEND CMAKE_CXX_FLAGS " /Zc:inline") # Enforce inline semantics
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:alignedNew") # Enforce aligned new/delete
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:auto") # Enforce 'auto' type deduction
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:__cplusplus") # Correct __cplusplus macro value
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:externC") # Enforce extern "C" linkage rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:externConstexpr") # Enforce extern constexpr rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:forScope") # Enforce for-loop scope rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:hiddenFriend") # Enforce hidden friend functions
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:implicitNoexcept") # Enforce implicit noexcept
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:lambda") # Enforce lambda rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:noexceptTypes") # Enforce noexcept type rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:preprocessor") # Enforce preprocessor rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:referenceBinding") # Enforce reference binding rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:rvalueCast") # Enforce rvalue cast rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:sizedDealloc") # Enforce sized deallocation
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:strictStrings") # Enforce strict string rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:ternary") # Enforce ternary operator rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:threadSafeInit") # Enforce thread-safe initialization
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:trigraphs") # Enforce trigraph rules
    #string(APPEND CMAKE_CXX_FLAGS " /Zc:wchar_t") # Enforce wchar_t rules


    # Apply critical flags to all build configurations (Debug/Release, C/C++)
    # This ensures consistency and overrides CMake defaults that may vary by configuration
    foreach(flag_var
        CMAKE_C_FLAGS_RELEASE CMAKE_C_FLAGS_DEBUG
        CMAKE_CXX_FLAGS_RELEASE CMAKE_CXX_FLAGS_DEBUG)
        # Remove any existing exception handling flags and apply /EHa (asynchronous)
        string(REGEX REPLACE "/EH[scra-z]+" "" ${flag_var} "${${flag_var}}")
        string(APPEND ${flag_var} " /EHa /bigobj")
        # Switch from dynamic (/MD) to static (/MT) runtime linking
        # This eliminates dependency on MSVC redistributables for end users
        #string(REPLACE "/MD" "/MT" ${flag_var} "${${flag_var}}")
    endforeach()

    # Preset overrides can replace CMake's standard MSVC Release defaults.
    # Preserve explicit optimization choices, but supply the expected Release
    # optimization and assertion settings when no choice is present.
    foreach(flag_var CMAKE_C_FLAGS_RELEASE CMAKE_CXX_FLAGS_RELEASE)
        string(TOUPPER "${${flag_var}}" normalized_flags)
        if(NOT normalized_flags MATCHES "(^|[ \t])[-/]DNDEBUG($|[ \t])")
            string(APPEND ${flag_var} " /DNDEBUG")
        endif()
        if(NOT normalized_flags MATCHES "(^|[ \t])[-/]O[12XD]($|[ \t])")
            string(APPEND ${flag_var} " /O2")
        endif()
    endforeach()

    # Debug info stays in the objects (/Z7, for LTCG compatibility), but a Release link
    # produces no PDB unless the target opts in with enable_release_pdb_for_target()
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /Z7")
    foreach(flag_var CMAKE_EXE_LINKER_FLAGS_RELEASE CMAKE_SHARED_LINKER_FLAGS_RELEASE)
        string(REGEX REPLACE "(^|[ \t])[-/]DEBUG(:[A-Za-z]+)?($|[ \t])" " " ${flag_var} "${${flag_var}}")
        string(APPEND ${flag_var} " /OPT:REF /OPT:ICF")
    endforeach()

endif()

# Apply LTO flags (/GL compile + /LTCG link) to a specific target for Release builds.
# Call this after defining each target that should use link-time optimization.
function(enable_lto_for_target target)
    if(MSVC AND ENABLE_LTO)
        target_compile_options(${target} PRIVATE $<$<CONFIG:Release>:/GL>)
        target_link_options(${target} PRIVATE $<$<CONFIG:Release>:/LTCG>)
    endif()
endfunction()

# Give a Release target a PDB. 
function(enable_release_pdb_for_target target)
    if(MSVC)
        target_link_options(${target} PRIVATE $<$<CONFIG:Release>:/DEBUG>)
    endif()
endfunction()
