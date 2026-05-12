#!/bin/bash

# =================================================================
# 极客嵌入式开发环境一键安装脚本 (STM32/STM8 + AI Agent + Codex CLI)
# 支持平台: macOS, Linux, Windows (Git Bash)
# 特性: 智能合并 settings.json，下发全局 Codex CLI，强制 Node.js 22+
# =================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}开始配置极客嵌入式开发环境（全链路 AI 极客版）...${NC}"

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

# 2. 核心工具链与 CLI 环境安装
install_tools() {
    case $OS_TYPE in
        "linux")
            echo -e "${BLUE}执行 Linux (apt) 安装...${NC}"
            sudo apt update
            # 先安装 curl 和基础工具 (去除系统自带的旧版 nodejs)
            sudo apt install -y curl cmake ninja-build gcc-arm-none-eabi gdb-multiarch sdcc git python3 python3-pip
            
            # 通过 NodeSource 强制安装 Node.js 22.x
            echo -e "${BLUE}注入 NodeSource 源，强制安装 Node.js 22.x...${NC}"
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt install -y nodejs
            ;;
        "macos")
            echo -e "${BLUE}执行 macOS (brew) 安装...${NC}"
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}错误: 未检测到 Homebrew${NC}"
                exit 1
            fi
            # brew install node 默认拉取最新版 (>= 22)
            brew install cmake ninja gcc-arm-embedded sdcc git python3 node
            ;;
        "windows")
            echo -e "${BLUE}执行 Windows (winget) 安装...${NC}"
            echo -e "${YELLOW}请确保以管理员权限运行 Git Bash${NC}"
            winget install -e --id Kitware.CMake
            winget install -e --id Ninja-build.Ninja
            winget install -e --id Arm.GnuEmbeddedToolchain
            winget install -e --id GNU.GDB
            winget install -e --id SDCC.SDCC
            winget install -e --id Git.Git
            winget install -e --id Python.Python.3.11
            # OpenJS.NodeJS 默认拉取最新稳定版 (>= 22)
            winget install -e --id OpenJS.NodeJS
            ;;
    esac

    echo -e "${BLUE}正在安装终端 AI 助手 (Codex CLI)...${NC}"
    if command -v npm &> /dev/null; then
        npm install -g codex-cli 
    elif command -v pip3 &> /dev/null; then
        pip3 install codex-cli
    else
        echo -e "${RED}警告: 未找到 npm 或 pip3，跳过 Codex CLI 本体安装。${NC}"
    fi
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

# 4. JSON 智能合并函数
merge_settings_json() {
    local target=".vscode/settings.json"
    local source=".temp_skills_repo/settings.json"
    
    local py_cmd="python3"
    if ! command -v python3 &> /dev/null; then
        py_cmd="python"
    fi

    if [ -f "$source" ]; then
        echo -e "${BLUE}智能合并 VS Code settings.json 配置...${NC}"
        $py_cmd -c "
import json, os
target_file = '$target'
source_file = '$source'
base_data = {}
if os.path.exists(target_file):
    try:
        with open(target_file, 'r', encoding='utf-8') as f:
            base_data = json.load(f)
    except Exception:
        pass
try:
    with open(source_file, 'r', encoding='utf-8') as f:
        new_data = json.load(f)
    base_data.update(new_data)
    with open(target_file, 'w', encoding='utf-8') as f:
        json.dump(base_data, f, indent=4, ensure_ascii=False)
    print('✅ settings.json 增量合并成功！')
except Exception as e:
    print(f'❌ settings.json 合并失败: {str(e)}')
"
    fi
}

# 5. 项目架构生成与全局配置下发
scaffold_and_pull() {
    echo -e "${BLUE}初始化工程基础架构...${NC}"
    mkdir -p .vscode
    mkdir -p .github/skills
    
    # --- 核心架构目录生成 ---
    mkdir -p App
    mkdir -p BSP
    mkdir -p Core
    mkdir -p Drivers

    if [ ! -f "bsp_bridge.h" ]; then
        echo "/* AI Context Anchor - 真理之源 */" > bsp_bridge.h
        echo "#pragma once" >> bsp_bridge.h
        echo "#include \"main.h\"" >> bsp_bridge.h
    fi

    echo -e "${BLUE}从 GitHub 拉取技能库及配置文件...${NC}"
    rm -rf .temp_skills_repo
    if git clone https://github.com/kendiyang/embedded-systems.git .temp_skills_repo; then
        
        # 1. 下发全局 Codex CLI 配置
        echo -e "${BLUE}配置 Codex CLI 用户级鉴权与设置...${NC}"
        if [ -f ".temp_skills_repo/config.toml" ]; then
            mkdir -p ~/.codex
            cp -rf .temp_skills_repo/config.toml ~/.codex/
            echo -e "${GREEN}✅ 成功注入全局配置: ~/.codex/config.toml${NC}"
        else
            echo -e "${YELLOW}未在仓库中找到 config.toml，跳过 Codex CLI 配置。${NC}"
        fi

        # 2. 分发 .md 技能文件
        cp -r .temp_skills_repo/*.md .github/skills/ 2>/dev/null
        
        # 3. 注入工程级生产配置
        echo -e "${BLUE}注入工程级生产配置...${NC}"
        [ -f ".temp_skills_repo/copilot-instructions.md" ] && cp .temp_skills_repo/copilot-instructions.md .github/
        [ -f ".temp_skills_repo/c_cpp_properties.json" ] && cp .temp_skills_repo/c_cpp_properties.json .vscode/
        [ -f ".temp_skills_repo/tasks.json" ] && cp .temp_skills_repo/tasks.json .vscode/
        [ -f ".temp_skills_repo/CMakeLists.txt" ] && cp .temp_skills_repo/CMakeLists.txt ./
        [ -f ".temp_skills_repo/.clang-format" ] && cp .temp_skills_repo/.clang-format ./
        [ -f ".temp_skills_repo/.clang-tidy" ] && cp .temp_skills_repo/.clang-tidy ./
        
        # 4. 执行智能合并
        merge_settings_json
        
        # 5. 清理现场
        rm -rf .temp_skills_repo
        echo -e "${GREEN}仓库资源与全局配置部署成功！${NC}"
    else
        echo -e "${RED}警告: 仓库拉取失败，跳过配置下发。${NC}"
    fi
}

# --- 执行流水线 ---
install_tools
install_vscode_extensions
scaffold_and_pull

# 最终版本检查
echo -e "${BLUE}检查 Node.js 版本...${NC}"
node_version=$(node -v 2>/dev/null)
echo -e "${GREEN}当前 Node.js 版本: ${node_version}${NC}"

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}全栈环境、全局 AI CLI 与项目配置下发完成！${NC}"
echo -e "${GREEN}1. 你现在可以在终端中直接使用 Codex CLI。${NC}"
echo -e "${GREEN}2. 在 VS Code 中按 Ctrl+Shift+B 测试构建体系。${NC}"
echo -e "${GREEN}========================================================================${NC}"
