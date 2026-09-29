# 将本段粘贴到工程根目录 CMakeLists.txt，替换原来的用户 target_sources() 段。
#
# 只收集 Core/Src 一级目录中的用户 .c 文件；CubeMX 已管理的文件必须排除，
# 否则会发生重复编译和重复符号。新增的 bsp/App 等目录请显式加入 CMake。

set(MX_MANAGED_SRC
    main.c
    stm32f1xx_it.c
    stm32f1xx_hal_msp.c
    sysmem.c
    syscalls.c
    system_stm32f1xx.c
)

file(GLOB USER_SRC_FILES CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/Core/Src/*.c"
)

foreach(_src IN LISTS USER_SRC_FILES)
    get_filename_component(_name "${_src}" NAME)
    if(NOT _name IN_LIST MX_MANAGED_SRC)
        list(APPEND USER_SOURCES "${_src}")
    endif()
endforeach()

target_sources(${CMAKE_PROJECT_NAME} PRIVATE ${USER_SOURCES})
