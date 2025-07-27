cmake_minimum_required(VERSION 3.16)

project(buff VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick)

add_executable(app
    main.cpp
    checks/D01NoRootPropertiesForComposerObjects.cpp  checks/D01NoRootPropertiesForComposerObjects.h
    checks/D02NoNonTrivialJSBindingForProperties.cpp  checks/D02NoNonTrivialJSBindingForProperties.h
    checks/D03NoCppBindingsForProperties.cpp          checks/D03NoCppBindingsForProperties.h
    checks/D04NoCppInSignalHandler.cpp                checks/D04NoCppInSignalHandler.h
)

target_include_directories(app PUBLIC checks)

set_target_properties(app PROPERTIES
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(app
    Qt6::Core
    Qt6::Quick
)

include(GNUInstallDirs)
install(TARGETS app
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
