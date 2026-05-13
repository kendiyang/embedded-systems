cmake_minimum_required(VERSION 3.16)

# =================================================================
# 1. 平台选择与交叉编译配置 (必须放在 project 声明之前)
# =================================================================
# 支持通过命令行传参: -DTARGET_MCU=STM8 或 STM32
set(TARGET_MCU "STM32" CACHE STRING "Target MCU family: STM32 or STM8")

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# 修复点：添加双引号增强 CMake 语法健壮性
if("${TARGET_MCU}" STREQUAL "STM32")
    set(CMAKE_SYSTEM_PROCESSOR arm)
    set(CMAKE_C_COMPILER arm-none-eabi-gcc)
    set(CMAKE_CXX_COMPILER arm-none-eabi-g++)
    set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)
elseif("${TARGET_MCU}" STREQUAL "STM8")
    set(CMAKE_SYSTEM_PROCESSOR stm8)
    set(CMAKE_C_COMPILER sdcc)
endif()

project(GeekEmbeddedProject C CXX ASM)

# 强制导出编译数据库供 AI 建立硬件索引 (防幻觉核心)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# =================================================================
# 2. 自动目录扫描与屏蔽逻辑
# =================================================================
set(AUTO_SCAN_DIRS "Core" "Drivers" "BSP" "App")
set(ALL_SOURCES "")
set(ALL_INC_DIRS "")

foreach(DIR ${AUTO_SCAN_DIRS})
    # 递归收集源文件
    file(GLOB_RECURSE DIR_SOURCES CONFIGURE_DEPENDS "${DIR}/*.c")
    list(APPEND ALL_SOURCES ${DIR_SOURCES})

    # 递归收集头文件路径
    file(GLOB_RECURSE DIR_HEADERS CONFIGURE_DEPENDS "${DIR}/*.h")
    foreach(HEADER_FILE ${DIR_HEADERS})
        get_filename_component(HEADER_DIR ${HEADER_FILE} DIRECTORY)
        list(APPEND ALL_INC_DIRS ${HEADER_DIR})
    endforeach()
endforeach()

# 极客屏蔽位：排除以下划线 '_' 或点 '.' 开头的目录
# 修复点：使用 [.] 替代 \\. 彻底解决 VS Code CMake 插件的误判报错
list(FILTER ALL_SOURCES EXCLUDE REGEX "/[_.].*")
list(FILTER ALL_INC_DIRS EXCLUDE REGEX "/[_.].*")
list(REMOVE_DUPLICATES ALL_INC_DIRS)

# =================================================================
# 3. 目标构建与平台参数分流
# =================================================================
add_executable(${PROJECT_NAME}.elf ${ALL_SOURCES})
target_include_directories(${PROJECT_NAME}.elf PRIVATE ${ALL_INC_DIRS})

if("${TARGET_MCU}" STREQUAL "STM32")
    target_compile_definitions(${PROJECT_NAME}.elf PRIVATE STM32 STM32F4xx)
    # STM32 参数 (Cortex-M4 示例)
    # 修复点：去除双引号！让其作为 CMake List 数组传递，避免 GCC 将所有参数当成一个连体字符串而报错
    set(MCU_FLAGS -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard)
    
    target_compile_options(${PROJECT_NAME}.elf PRIVATE ${MCU_FLAGS} -Os -Wall -Wextra -fdata-sections -ffunction-sections)
    target_link_options(${PROJECT_NAME}.elf PRIVATE ${MCU_FLAGS} -Wl,--gc-sections)

    # 固件转换: .elf -> .hex, .bin
    add_custom_command(TARGET ${PROJECT_NAME}.elf POST_BUILD
        COMMAND arm-none-eabi-objcopy -O ihex ${PROJECT_NAME}.elf ${PROJECT_NAME}.hex
        COMMAND arm-none-eabi-objcopy -O binary ${PROJECT_NAME}.elf ${PROJECT_NAME}.bin
        COMMAND arm-none-eabi-size ${PROJECT_NAME}.elf
    )

elseif("${TARGET_MCU}" STREQUAL "STM8")
    target_compile_definitions(${PROJECT_NAME}.elf PRIVATE STM8 STM8S103)
    # STM8 参数 (SDCC)
    target_compile_options(${PROJECT_NAME}.elf PRIVATE -mstm8 --opt-code-size)
    
    # 固件转换: .ihx -> .hex, .s19
    add_custom_command(TARGET ${PROJECT_NAME}.elf POST_BUILD
        COMMAND packihx ${PROJECT_NAME}.ihx > ${PROJECT_NAME}.hex
        COMMAND sdobjcopy -I ihex -O srec ${PROJECT_NAME}.ihx ${PROJECT_NAME}.s19
    )
endif()
