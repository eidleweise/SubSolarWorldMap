cmake_minimum_required(VERSION 3.16)

project(SubSolarWorldMap VERSION 0.1.0)

include(GNUInstallDirs)

string(TIMESTAMP BUILD_TIMESTAMP "%Y-%m-%d %H:%M:%S %z")
configure_file(
    package/contents/js/buildInfo.js.in
    "${CMAKE_CURRENT_BINARY_DIR}/generated/buildInfo.js"
    @ONLY
)

find_program(NODE_EXECUTABLE NAMES node)
if(NODE_EXECUTABLE)
    enable_testing()
    add_test(
        NAME solar-math
        COMMAND "${NODE_EXECUTABLE}" --test
            "${CMAKE_CURRENT_SOURCE_DIR}/tests/solarMath.test.js"
    )
endif()

set(PLASMOID_ID org.eidleweise.subsolarworldmap)

set(PLASMOID_INSTALL_DIR
    "${CMAKE_INSTALL_DATADIR}/plasma/plasmoids/${PLASMOID_ID}")

find_program(QSB_EXECUTABLE NAMES qsb qsb-qt6)

if(QSB_EXECUTABLE)
    set(SHADER_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/package/contents/shaders/dayNight.frag")
    set(SHADER_BINARY "${CMAKE_CURRENT_SOURCE_DIR}/package/contents/shaders/dayNight.frag.qsb")

    add_custom_command(
        OUTPUT "${SHADER_BINARY}"
        COMMAND "${QSB_EXECUTABLE}" --qt6 --qsbversion 64
            -o "${SHADER_BINARY}" "${SHADER_SOURCE}"
        DEPENDS "${SHADER_SOURCE}"
        COMMENT "Compiling the day/night fragment shader"
        VERBATIM
    )
    add_custom_target(compile_shaders ALL DEPENDS "${SHADER_BINARY}")
else()
    message(WARNING "qsb was not found; using the checked-in dayNight.frag.qsb")
endif()

install(FILES package/metadata.json
    DESTINATION "${PLASMOID_INSTALL_DIR}")
install(DIRECTORY package/contents/ui package/contents/js package/contents/config
    DESTINATION "${PLASMOID_INSTALL_DIR}/contents")
install(DIRECTORY package/contents/shaders
    DESTINATION "${PLASMOID_INSTALL_DIR}/contents")
install(FILES
    package/contents/assets/day/world.equirectangular-2160x1080.png
    package/contents/assets/day/world.equirectangular-3840x1920.png
    DESTINATION "${PLASMOID_INSTALL_DIR}/contents/assets/day")
install(FILES
    package/contents/assets/night/BlackMarble.equirectangular-2160x1080.png
    package/contents/assets/night/BlackMarble.equirectangular-3840x1920.png
    DESTINATION "${PLASMOID_INSTALL_DIR}/contents/assets/night")
