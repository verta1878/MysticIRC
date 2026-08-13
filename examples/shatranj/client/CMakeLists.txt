cmake_minimum_required(VERSION 3.22)

# Fail fast on the known-bad configuration instead of hanging for minutes:
# Dropbox sync locks stall cmake configure/build inside the synced tree.
# Placed before project() so the abort is instant (no compiler detection).
string(FIND "${CMAKE_BINARY_DIR}" "Dropbox" _nczx_dropbox_pos)
if(NOT _nczx_dropbox_pos EQUAL -1)
    message(FATAL_ERROR
        "Build dir is inside Dropbox: sync locks hang builds. "
        "Use client/build-pc.cmd (configure+build+ctest, incremental) "
        "or, from client/: cmake --preset msvc")
endif()

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/../VERSION"
    SHATRANJ_SOURCE_VERSION LIMIT_COUNT 1)
string(STRIP "${SHATRANJ_SOURCE_VERSION}" SHATRANJ_SOURCE_VERSION)
if(SHATRANJ_SOURCE_VERSION MATCHES "^([0-9]+\\.[0-9]+)(-dev([0-9][0-9][0-9]|ESP))?$")
    set(SHATRANJ_PROJECT_VERSION "${CMAKE_MATCH_1}.0")
    set(SHATRANJ_BUNDLE_SHORT_VERSION "${CMAKE_MATCH_1}")
elseif(SHATRANJ_SOURCE_VERSION MATCHES "^([0-9]+\\.[0-9]+\\.[0-9]+)(-dev([0-9][0-9][0-9]|ESP))?$")
    set(SHATRANJ_PROJECT_VERSION "${CMAKE_MATCH_1}")
    set(SHATRANJ_BUNDLE_SHORT_VERSION "${CMAKE_MATCH_1}")
else()
    message(FATAL_ERROR
        "VERSION must contain major.minor[-devNNN|-devESP] or "
        "major.minor.patch[-devNNN|-devESP]")
endif()
set(SHATRANJ_DISPLAY_VERSION "${SHATRANJ_SOURCE_VERSION}")

project(Shatranj VERSION "${SHATRANJ_PROJECT_VERSION}" LANGUAGES C CXX)

set(SHATRANJ_WINDOWS_RESOURCE "${CMAKE_CURRENT_BINARY_DIR}/shatranj.rc")
set(SHATRANJ_WINDOWS_ICON "${CMAKE_CURRENT_SOURCE_DIR}/shatranj.ico")
configure_file(shatranj.rc.in "${SHATRANJ_WINDOWS_RESOURCE}" @ONLY)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core Widgets Network Svg)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Widgets Network Svg)

# All shared C sources are globbed: every refactor phase adds files under
# src/common and a hand-maintained list drifts (recurring unresolved-symbol
# link failures). CONFIGURE_DEPENDS re-runs the glob at build time.
file(GLOB SHATRANJ_COMMON_SOURCES CONFIGURE_DEPENDS
    ../src/common/*/*.c
)

add_library(shatranj-common STATIC ${SHATRANJ_COMMON_SOURCES})
target_include_directories(shatranj-common PUBLIC ../src)
set_target_properties(shatranj-common PROPERTIES
    C_STANDARD 99
    C_STANDARD_REQUIRED ON
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
)

set(SHATRANJ_DESKTOP_CORE_SOURCES
    ../src/pc/client/chess_helpers.cpp
    ../src/pc/client/desktop_session_controller.cpp
    ../src/pc/client/desktop_transport_codec.cpp
    ../src/pc/client/direct_session_adapter.cpp
    ../src/pc/client/mqtt_session_adapter.cpp
    ../src/pc/client/save_game_store.cpp
    ../src/pc/client/chess_helpers.h
    ../src/pc/client/desktop_session_controller.h
    ../src/pc/client/desktop_transport_codec.h
    ../src/pc/client/direct_session_adapter.h
    ../src/pc/client/mqtt_session_adapter.h
    ../src/pc/client/save_game_store.h
)

add_library(shatranj-desktop-core STATIC ${SHATRANJ_DESKTOP_CORE_SOURCES})
target_include_directories(shatranj-desktop-core PUBLIC ../src)
target_link_libraries(shatranj-desktop-core
    PUBLIC
        shatranj-common
        Qt${QT_VERSION_MAJOR}::Core
    PRIVATE
        Qt${QT_VERSION_MAJOR}::Network
)
set_target_properties(shatranj-desktop-core PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
)

set(SHATRANJ_CLIENT_UI_SOURCES
    ../src/pc/client/main.cpp
    ../src/pc/client/main_window.cpp
    ../src/pc/client/app_banner.cpp
    ../src/pc/client/piece_renderer.cpp
    ../src/pc/client/main_window.h
    ../src/pc/client/app_banner.h
    ../src/pc/client/piece_renderer.h
)

if(WIN32)
    list(APPEND SHATRANJ_CLIENT_UI_SOURCES "${SHATRANJ_WINDOWS_RESOURCE}")
elseif(APPLE)
    enable_language(OBJCXX)
    list(APPEND SHATRANJ_CLIENT_UI_SOURCES
        ../src/pc/client/mac_window_chrome.h
        ../src/pc/client/mac_window_chrome.mm
    )
    list(APPEND SHATRANJ_CLIENT_UI_SOURCES shatranj.icns)
    set_source_files_properties(shatranj.icns PROPERTIES
        MACOSX_PACKAGE_LOCATION Resources
    )
endif()

if(QT_VERSION_MAJOR EQUAL 6)
    qt_standard_project_setup()
    qt_add_executable(shatranj-client ${SHATRANJ_CLIENT_UI_SOURCES})
else()
    add_executable(shatranj-client ${SHATRANJ_CLIENT_UI_SOURCES})
endif()

# No .ui files in this project; AUTOUIC would misread src/common/ui_messages.h
# (ui_ prefix) as a uic-generated header and demand a missing messages.ui.
set_target_properties(shatranj-client PROPERTIES AUTOUIC OFF)

target_include_directories(shatranj-client PRIVATE
    ../src
)
target_compile_definitions(shatranj-client PRIVATE
    NETCHESSZX_APP_VERSION="${SHATRANJ_DISPLAY_VERSION}"
)

target_link_libraries(shatranj-client PRIVATE
    shatranj-desktop-core
    Qt${QT_VERSION_MAJOR}::Widgets
    Qt${QT_VERSION_MAJOR}::Network
    Qt${QT_VERSION_MAJOR}::Svg
)

set(SHATRANJ_DESKTOP_ASSET_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/../assets/pc-client")
set(SHATRANJ_DESKTOP_PIECE_SETS california gioco kiwen-suwi merida mpchess)
set(SHATRANJ_DESKTOP_BOARDS blue.png blue3.jpg green.png purple-diag.png wood4.jpg)
if(APPLE)
    set(SHATRANJ_DESKTOP_ASSET_DEST
        "$<TARGET_BUNDLE_CONTENT_DIR:shatranj-client>/Resources/assets/pc-client")
else()
    set(SHATRANJ_DESKTOP_ASSET_DEST
        "$<TARGET_FILE_DIR:shatranj-client>/assets/pc-client")
endif()

add_custom_command(TARGET shatranj-client POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${SHATRANJ_DESKTOP_ASSET_DEST}"
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "${SHATRANJ_DESKTOP_ASSET_DEST}/piece_sets"
            "${SHATRANJ_DESKTOP_ASSET_DEST}/boards"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${SHATRANJ_DESKTOP_ASSET_SOURCE}/about"
            "${SHATRANJ_DESKTOP_ASSET_DEST}/about"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${SHATRANJ_DESKTOP_ASSET_SOURCE}/pieces"
            "${SHATRANJ_DESKTOP_ASSET_DEST}/pieces"
    COMMENT "Staging shared desktop assets"
    VERBATIM
)
foreach(piece_set IN LISTS SHATRANJ_DESKTOP_PIECE_SETS)
    add_custom_command(TARGET shatranj-client POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${SHATRANJ_DESKTOP_ASSET_SOURCE}/piece_sets/${piece_set}"
                "${SHATRANJ_DESKTOP_ASSET_DEST}/piece_sets/${piece_set}"
        VERBATIM
    )
endforeach()
foreach(board IN LISTS SHATRANJ_DESKTOP_BOARDS)
    add_custom_command(TARGET shatranj-client POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${SHATRANJ_DESKTOP_ASSET_SOURCE}/boards/${board}"
                "${SHATRANJ_DESKTOP_ASSET_DEST}/boards/${board}"
        VERBATIM
    )
endforeach()

include(CTest)
if(BUILD_TESTING)
    add_executable(shatranj-desktop-transport-codec-test
        ../tests/pc/test_desktop_transport_codec.cpp
    )
    target_include_directories(shatranj-desktop-transport-codec-test PRIVATE ../src)
    target_link_libraries(shatranj-desktop-transport-codec-test PRIVATE
        shatranj-desktop-core
    )
    set_target_properties(shatranj-desktop-transport-codec-test PROPERTIES
        AUTOMOC OFF
        AUTOUIC OFF
        AUTORCC OFF
    )
    add_test(NAME pc-desktop-transport-codec
             COMMAND shatranj-desktop-transport-codec-test)

    add_executable(shatranj-desktop-session-controller-test
        ../tests/pc/test_desktop_session_controller.cpp
    )
    target_include_directories(shatranj-desktop-session-controller-test PRIVATE ../src)
    target_link_libraries(shatranj-desktop-session-controller-test PRIVATE
        shatranj-desktop-core
    )
    set_target_properties(shatranj-desktop-session-controller-test PROPERTIES
        AUTOMOC OFF
        AUTOUIC OFF
        AUTORCC OFF
    )
    add_test(NAME pc-desktop-session-controller
             COMMAND shatranj-desktop-session-controller-test)

    add_executable(shatranj-save-game-store-test
        ../tests/pc/test_save_game_store.cpp
    )
    target_include_directories(shatranj-save-game-store-test PRIVATE ../src)
    target_link_libraries(shatranj-save-game-store-test PRIVATE
        shatranj-desktop-core
    )
    set_target_properties(shatranj-save-game-store-test PROPERTIES
        AUTOMOC OFF
        AUTOUIC OFF
        AUTORCC OFF
    )
    add_test(NAME pc-save-game-store COMMAND shatranj-save-game-store-test)

    add_executable(shatranj-chess-helpers-test
        ../tests/pc/test_chess_helpers.cpp
    )
    target_include_directories(shatranj-chess-helpers-test PRIVATE ../src)
    target_link_libraries(shatranj-chess-helpers-test PRIVATE
        shatranj-desktop-core
    )
    set_target_properties(shatranj-chess-helpers-test PROPERTIES
        AUTOMOC OFF
        AUTOUIC OFF
        AUTORCC OFF
    )
    add_test(NAME pc-chess-helpers COMMAND shatranj-chess-helpers-test)

    add_executable(shatranj-direct-adapter-test
        ../tests/pc/test_direct_session_adapter.cpp
    )
    target_include_directories(shatranj-direct-adapter-test PRIVATE ../src)
    target_link_libraries(shatranj-direct-adapter-test PRIVATE
        shatranj-desktop-core
        Qt${QT_VERSION_MAJOR}::Network
    )
    set_target_properties(shatranj-direct-adapter-test PROPERTIES
        AUTOMOC OFF
        AUTOUIC OFF
        AUTORCC OFF
    )
    add_test(NAME pc-direct-adapter COMMAND shatranj-direct-adapter-test)

    add_executable(shatranj-mqtt-adapter-test
        ../tests/pc/test_mqtt_session_adapter.cpp
    )
    target_include_directories(shatranj-mqtt-adapter-test PRIVATE ../src)
    target_link_libraries(shatranj-mqtt-adapter-test PRIVATE
        shatranj-desktop-core
    )
    set_target_properties(shatranj-mqtt-adapter-test PROPERTIES
        AUTOMOC OFF
        AUTOUIC OFF
        AUTORCC OFF
    )
    add_test(NAME pc-mqtt-adapter COMMAND shatranj-mqtt-adapter-test)

    set(SHATRANJ_MQTT_TX_FAILURE_SOURCES ${SHATRANJ_CLIENT_UI_SOURCES})
    list(REMOVE_ITEM SHATRANJ_MQTT_TX_FAILURE_SOURCES
        ../src/pc/client/main.cpp
        "${SHATRANJ_WINDOWS_RESOURCE}"
        shatranj.icns
    )
    add_executable(shatranj-mqtt-tx-failure-test
        ../tests/pc/test_mqtt_tx_failure.cpp
        ${SHATRANJ_MQTT_TX_FAILURE_SOURCES}
    )
    target_include_directories(shatranj-mqtt-tx-failure-test PRIVATE ../src)
    target_link_libraries(shatranj-mqtt-tx-failure-test PRIVATE
        shatranj-desktop-core
        Qt${QT_VERSION_MAJOR}::Widgets
        Qt${QT_VERSION_MAJOR}::Network
        Qt${QT_VERSION_MAJOR}::Svg
    )
    target_compile_definitions(shatranj-mqtt-tx-failure-test PRIVATE
        NETCHESSZX_APP_VERSION="${SHATRANJ_DISPLAY_VERSION}"
        NETCHESSZX_PC_MQTT_TX_FAILURE_TEST=1
    )
    set_target_properties(shatranj-mqtt-tx-failure-test PROPERTIES AUTOUIC OFF)
    add_test(NAME pc-mqtt-tx-failure COMMAND shatranj-mqtt-tx-failure-test)

    add_test(NAME pc-client-assets
        COMMAND ${CMAKE_COMMAND} -E compare_files
                "${SHATRANJ_DESKTOP_ASSET_SOURCE}/piece_sets/merida/wK.svg"
                "${SHATRANJ_DESKTOP_ASSET_DEST}/piece_sets/merida/wK.svg"
    )

    if(WIN32)
        # Qt DLLs live outside the build tree; without this, ctest fails with
        # STATUS_DLL_NOT_FOUND (0xc0000135) unless the caller hand-edits PATH.
        set_tests_properties(pc-desktop-session-controller
                             pc-desktop-transport-codec
                             pc-save-game-store
                             pc-chess-helpers
                             pc-direct-adapter
                             pc-mqtt-adapter
                             pc-mqtt-tx-failure PROPERTIES
            ENVIRONMENT_MODIFICATION
            "PATH=path_list_prepend:$<TARGET_FILE_DIR:Qt${QT_VERSION_MAJOR}::Core>"
        )
    endif()
endif()

set_target_properties(shatranj-client PROPERTIES
    WIN32_EXECUTABLE TRUE
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
    MACOSX_BUNDLE_BUNDLE_NAME "Shatranj"
    MACOSX_BUNDLE_GUI_IDENTIFIER "io.github.ignaciomonge.shatranj"
    MACOSX_BUNDLE_ICON_FILE "shatranj.icns"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${SHATRANJ_BUNDLE_SHORT_VERSION}"
)

if(UNIX AND NOT APPLE)
    include(GNUInstallDirs)
    install(TARGETS shatranj-client
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
    install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/assets"
        DESTINATION "${CMAKE_INSTALL_BINDIR}")
    install(FILES io.github.ignaciomonge.shatranj.desktop
        DESTINATION "${CMAKE_INSTALL_DATADIR}/applications")
    install(FILES shatranj.png
        DESTINATION "${CMAKE_INSTALL_DATADIR}/pixmaps"
        RENAME shatranj.png)
endif()
