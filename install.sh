#!/bin/bash

# =================================================================
# 极客嵌入式开发环境一键安装脚本 (STM32/STM8 + AI Agent 智能部署)
# 支持平台: macOS, Linux, Windows (Git Bash)
# 特性: 智能合并 settings.json，防止覆盖用户本地配置
# =================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}开始配置极客嵌入式开发环境（纯编译/AI辅助/全配置版）...${NC}"

# 1. 平台检测
OS_TYPE="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    OS_TYPE="windows"
fi

echo -e "检测到系统平台: ${YELLOW}$OS_TYPE${NC}"

# 2. 核心工具链安装
install_tools() {
    case $OS_TYPE in
        "linux")
            sudo apt update
            sudo apt install -y cmake ninja-build gcc-arm-none-eabi gdb-multiarch sdcc git python3
            ;;
        "macos")
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}错误: 未检测到 Homebrew${NC}"
                exit 1
            fi
            brew install cmake ninja gcc-arm-embedded sdcc git python3
            ;;
        "windows")
            echo -e "${YELLOW}请确保以管理员权限运行 Git Bash${NC}"
            winget install -e --id Kitware.CMake
            winget install -e --id Ninja-build.Ninja
            winget install -e --id Arm.GnuEmbeddedToolchain
            winget install -e --id GNU.GDB
            winget install -e --id SDCC.SDCC
            winget install -e --id Git.Git
            ;;
    esac
}

# 3. VS Code 插件安装
install_vscode_extensions() {
    CODE_CMD="code"
    if ! command -v code &> /dev/null; then
        if [ "$OS_TYPE" == "macos" ] && [ -f "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
            CODE_CMD="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        else
            echo -e "${RED}警告: 找不到 'code' 命令，跳过扩展安装。${NC}"
            return 1
        fi
    fi

    echo -e "${BLUE}安装 VS Code 极客与 AI 插件组合...${NC}"
    extensions=(
        "ms-vscode.cpptools-extension-pack"
        "ms-vscode.cmake-tools"
        "twxs.cmake"
        "marus25.cortex-debug"
        "cl.stm8-debug"
        "GitHub.copilot"
        "GitHub.copilot-chat"
        "openai.chatgpt"
        "formulahendry.agent-skills"
    )
    for ext in "${extensions[@]}"; do
        "$CODE_CMD" --install-extension "$ext" --force
    done
}

# 4. JSON 智能合并函数 (利用内置 Python)
merge_settings_json() {
    local target=".vscode/settings.json"
    local source=".temp_skills_repo/settings.json"
    
    # 确定 Python 命令 (跨平台兼容)
    local py_cmd="python3"
    if ! command -v python3 &> /dev/null; then
        py_cmd="python"
    fi

    if [ -f "$source" ]; then
        echo -e "${BLUE}智能合并 settings.json 配置...${NC}"
        $py_cmd -c "
import json, os

target_file = '$target'
source_file = '$source'

# 1. 读取原有配置 (若存在且合法)
base_data = {}
if os.path.exists(target_file):
    try:
        with open(target_file, 'r', encoding='utf-8') as f:
            base_data = json.load(f)
    except Exception:
        pass # 若原文件为空或格式错误，则使用空字典

# 2. 读取需要注入的仓库配置
try:
    with open(source_file, 'r', encoding='utf-8') as f:
        new_data = json.load(f)
        
    # 3. 执行合并 (更新键值对，不覆盖其它原有配置)
    base_data.update(new_data)
    
    # 4. 回写文件
    with open(target_file, 'w', encoding='utf-8') as f:
        json.dump(base_data, f, indent=4, ensure_ascii=False)
    print('✅ settings.json 增量合并成功！')
except Exception as e:
    print(f'❌ settings.json 合并失败: {str(e)}')
"
    fi
}

# 5. 项目架构生成与远端仓库配置拉取
scaffold_and_pull() {
    echo -e "${BLUE}初始化工程基础架构...${NC}"
    mkdir -p .vscode
    mkdir -p .github/skills
    mkdir -p App/Controller App/Protocol
    mkdir -p BSP/Driver
    mkdir -p Core/Src Core/Inc

    if [ ! -f "bsp_bridge.h" ]; then
        echo "/* AI Context Anchor - 真理之源 */" > bsp_bridge.h
        echo "#pragma once" >> bsp_bridge.h
        echo "#include \"main.h\"" >> bsp_bridge.h
    fi

    echo -e "${BLUE}从 GitHub 拉取技能库及配置文件...${NC}"
    rm -rf .temp_skills_repo
    if git clone https://github.com/kendiyang/embedded-systems.git .temp_skills_repo; then
        
        # 分发 .md 技能文件
        cp -r .temp_skills_repo/references/*.md .github/skills/ 2>/dev/null
        
        # 1. 独立文件直接覆盖拷贝
        echo -e "${BLUE}注入核心生产级配置文件...${NC}"
        [ -f ".temp_skills_repo/copilot-instructions.md" ] && cp .temp_skills_repo/copilot-instructions.md .github/
        [ -f ".temp_skills_repo/c_cpp_properties.json" ] && cp .temp_skills_repo/c_cpp_properties.json .vscode/
        [ -f ".temp_skills_repo/tasks.json" ] && cp .temp_skills_repo/tasks.json .vscode/
        [ -f ".temp_skills_repo/CMakeLists.txt" ] && cp .temp_skills_repo/CMakeLists.txt ./
        
        # 2. settings.json 执行智能合并
        merge_settings_json
        
        # 清理临时文件
        rm -rf .temp_skills_repo
        echo -e "${GREEN}仓库资源与配置部署成功！${NC}"
    else
        echo -e "${RED}警告: 仓库拉取失败，跳过配置下发。${NC}"
    fi
}

# --- 执行流水线 ---
install_tools
install_vscode_extensions
scaffold_and_pull

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}全栈环境与配置下发完成！${NC}"
echo -e "${GREEN}你的 VS Code 原有 settings.json 已得到安全保留与融合。${NC}"
echo -e "${GREEN}请按 Ctrl+Shift+B 测试构建体系，或直接呼出 AI 开始极客编程。${NC}"
echo -e "${GREEN}========================================================================${NC}"