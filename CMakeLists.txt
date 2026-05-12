cmake_minimum_required(VERSION 3.16)
project(GeekEmbeddedProject C CXX ASM)

# 1. 极客配置：强制导出编译数据库供 AI 和 IntelliSense 读取 (核心防幻觉依赖)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# MCU 编译参数 (此处以 STM32 通用基准为例，根据具体芯片型号微调)
set(MCU_FLAGS "-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard")
set(CMAKE_C_FLAGS "${MCU_FLAGS} -Os -Wall -Wextra -fdata-sections -ffunction-sections")
set(CMAKE_EXE_LINKER_FLAGS "-Wl,--gc-sections")

# 2. 定义需要自动扫描的顶层目录
set(AUTO_SCAN_DIRS 
    "Core"
    "Drivers"
    "BSP"
    "App"
)

set(ALL_SOURCES "")
set(ALL_INC_DIRS "")

# 3. 动态扫描与 _ 前缀智能排除
foreach(DIR ${AUTO_SCAN_DIRS})
    file(GLOB_RECURSE DIR_SOURCES CONFIGURE_DEPENDS "${DIR}/*.c")
    list(APPEND ALL_SOURCES ${DIR_SOURCES})

    file(GLOB_RECURSE DIR_HEADERS CONFIGURE_DEPENDS "${DIR}/*.h")
    foreach(HEADER_FILE ${DIR_HEADERS})
        get_filename_component(HEADER_DIR ${HEADER_FILE} DIRECTORY)
        list(APPEND ALL_INC_DIRS ${HEADER_DIR})
    endforeach()
endforeach()

# 过滤掉路径中包含下划线 _ 或点 . 开头的目录（用于快速废弃/测试模块）
list(FILTER ALL_SOURCES EXCLUDE REGEX "/[_\\.].*")
list(FILTER ALL_INC_DIRS EXCLUDE REGEX "/[_\\.].*")
list(REMOVE_DUPLICATES ALL_INC_DIRS)

# 4. 生成目标可执行文件
add_executable(${PROJECT_NAME}.elf ${ALL_SOURCES})
target_include_directories(${PROJECT_NAME}.elf PRIVATE ${ALL_INC_DIRS})

# 5. 编译后自动生成固件文件并输出内存占用信息
add_custom_command(TARGET ${PROJECT_NAME}.elf POST_BUILD
    COMMAND arm-none-eabi-objcopy -O ihex ${PROJECT_NAME}.elf ${PROJECT_NAME}.hex
    COMMAND arm-none-eabi-objcopy -O binary ${PROJECT_NAME}.elf ${PROJECT_NAME}.bin
    COMMAND arm-none-eabi-size ${PROJECT_NAME}.elf
)
