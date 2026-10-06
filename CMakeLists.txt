cmake_minimum_required(VERSION 3.16)

project(SubSolarWorldMap VERSION 0.1.0)

include(GNUInstallDirs)
find_package(Qt6 REQUIRED COMPONENTS Concurrent Network Qml)
find_package(ZLIB REQUIRED)
set(CMAKE_AUTOMOC ON)
qt_policy(SET QTP0001 NEW)

qt_add_qml_module(citycatalogmanager
    URI SubSolar.CityCatalog
    VERSION 1.0
    PLUGIN_TARGET citycatalogplugin
    CLASS_NAME CityCatalogPlugin
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/qml/SubSolar/CityCatalog"
    SOURCES
        package/contents/citycatalog/citycatalogmanager.cpp
        package/contents/citycatalog/citycatalogmanager.h
)
target_link_libraries(citycatalogmanager PRIVATE
    Qt6::Concurrent
    Qt6::Network
    ZLIB::ZLIB
)
target_include_directories(citycatalogmanager PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/package/contents/citycatalog")
set_target_properties(citycatalogmanager citycatalogplugin PROPERTIES
    INSTALL_RPATH "$ORIGIN"
)

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
    add_test(
        NAME city-catalog
        COMMAND "${NODE_EXECUTABLE}" --test
            "${CMAKE_CURRENT_SOURCE_DIR}/tests/cityCatalog.test.js"
    )
    add_test(
        NAME map-projection
        COMMAND "${NODE_EXECUTABLE}" --test
            "${CMAKE_CURRENT_SOURCE_DIR}/tests/mapProjection.test.js"
    )
    add_test(
        NAME pin-appearance
        COMMAND "${NODE_EXECUTABLE}" --test
            "${CMAKE_CURRENT_SOURCE_DIR}/tests/pinAppearance.test.js"
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
    DESTINATION "${PLASMOID_INSTALL_DIR}/contents"
    PATTERN "*.in" EXCLUDE)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/generated/buildInfo.js"
    DESTINATION "${PLASMOID_INSTALL_DIR}/contents/js")
install(DIRECTORY package/contents/shaders
    DESTINATION "${PLASMOID_INSTALL_DIR}/contents")
install(TARGETS citycatalogmanager citycatalogplugin
    LIBRARY DESTINATION "${PLASMOID_INSTALL_DIR}/contents/lib/SubSolar/CityCatalog")
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/qml/SubSolar/CityCatalog/qmldir"
    DESTINATION "${PLASMOID_INSTALL_DIR}/contents/lib/SubSolar/CityCatalog")
install(FILES
    package/contents/assets/day/world.equirectangular-2160x1080.png
    package/contents/assets/day/world.equirectangular-3840x1920.png
    DESTINATION "${PLASMOID_INSTALL_DIR}/contents/assets/day")
install(FILES
    package/contents/assets/night/BlackMarble.equirectangular-2160x1080.png
    package/contents/assets/night/BlackMarble.equirectangular-3840x1920.png
    DESTINATION "${PLASMOID_INSTALL_DIR}/contents/assets/night")
