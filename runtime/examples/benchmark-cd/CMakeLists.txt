cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (benchmark-cd)

find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)

add_executable(benchmark-cd benchmark-cd.c)
set_tapasco_defaults(benchmark-cd)
target_link_libraries(benchmark-cd rt pthread tapasco platform)

install(TARGETS benchmark-cd
        RUNTIME DESTINATION share/Tapasco/bin/)
