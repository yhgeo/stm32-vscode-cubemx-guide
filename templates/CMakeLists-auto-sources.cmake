# ============================================================
# 自动收集用户源文件
#
# 用法：粘贴到工程根目录的 CMakeLists.txt，
#       替换掉原来那段 target_sources(...)
#
# 效果：往 Core/Src/ 里丢新的 .c 文件，直接编译就生效，
#       不用再回来改这个文件。头文件（.h）本来就不用登记，
#       放进 Core/Inc/ 就能被 include 到。
# ============================================================

# CubeMX 已经在 cmake/stm32cubemx/CMakeLists.txt 里登记过下面这些文件，
# 必须排除，否则同一个文件会被编译两次，链接时报重复符号。
set(MX_MANAGED_SRC
    main.c
    stm32f1xx_it.c
    stm32f1xx_hal_msp.c
    sysmem.c
    syscalls.c
    system_stm32f1xx.c
)

# CONFIGURE_DEPENDS：让构建工具每次检查目录变化，新增 .c 自动生效
file(GLOB USER_SRC_FILES CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/Core/Src/*.c"
)

foreach(_src ${USER_SRC_FILES})
    get_filename_component(_name "${_src}" NAME)
    if(NOT _name IN_LIST MX_MANAGED_SRC)
        list(APPEND USER_SOURCES "${_src}")
    endif()
endforeach()

target_sources(${CMAKE_PROJECT_NAME} PRIVATE ${USER_SOURCES})
