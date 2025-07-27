# CMake toolchain file for Qt Creator MinGW kit
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# Specify the cross compiler
set(CMAKE_C_COMPILER "C:/Qt/Tools/mingw1310_64/bin/gcc.exe")
set(CMAKE_CXX_COMPILER "C:/Qt/Tools/mingw1310_64/bin/g++.exe")

# Specify the build tools
set(CMAKE_MAKE_PROGRAM "C:/Qt/Tools/Ninja/ninja.exe")

# Where is the target environment located
set(CMAKE_FIND_ROOT_PATH "C:/Qt/Tools/mingw1310_64")

# Adjust the default behavior of the FIND_XXX() commands:
# search programs in the host environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

# search headers and libraries in the target environment
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Set Qt specific paths
set(QT_VERSION_MAJOR 6)
set(CMAKE_PREFIX_PATH "C:/Qt/6.9.1/mingw_64")

# Additional compiler flags for MinGW
set(CMAKE_CXX_FLAGS_INIT "-Wall -Wextra")
set(CMAKE_C_FLAGS_INIT "-Wall -Wextra")

# Enable static linking if needed (uncomment if required)
# set(CMAKE_EXE_LINKER_FLAGS_INIT "-static-libgcc -static-libstdc++")

# Set the resource compiler for Windows
set(CMAKE_RC_COMPILER "C:/Qt/Tools/mingw1310_64/bin/windres.exe")
