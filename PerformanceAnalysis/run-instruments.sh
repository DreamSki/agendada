#!/bin/bash

# Agendada Instruments 自动化测试脚本
# 用法: ./run-instruments.sh [scenario-name]
#
# 前提条件:
# 1. Xcode Command Line Tools 已安装
# 2. 已执行 swift build
# 3. 足够的磁盘空间（> 1GB）

set -e

PROJECT_ROOT="/Users/oosun/Documents/03 Resources/Agendada"
BUILD_PATH="$PROJECT_ROOT/.build/debug"
APP_NAME="Agendada"
RESULTS_DIR="$PROJECT_ROOT/PerformanceResults"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_info() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# 创建结果目录
mkdir -p "$RESULTS_DIR"

# 检查应用是否存在
if [ ! -e "$BUILD_PATH/$APP_NAME" ]; then
    print_error "应用未找到，正在构建..."
    cd "$PROJECT_ROOT"
    swift build
    print_info "构建完成"
fi

# 场景选择
SCENARIO=${1:-"baseline"}

case $SCENARIO in
    baseline)
        TRACE_NAME="baseline_idle"
        DURATION=30
        print_header "场景 1：基线测量"
        print_info "启动应用并录制 30 秒空闲状态"
        ;;

    notes)
        TRACE_NAME="notes_operations"
        DURATION=120
        print_header "场景 2：笔记操作"
        print_info "请在接下来的 2 分钟内："
        print_info "1. 创建 20 个笔记"
        print_info "2. 编辑标题和正文"
        print_info "3. 切换笔记"
        print_step "按 Enter 开始录制..."
        read
        ;;

    scroll)
        TRACE_NAME="scrolling"
        DURATION=120
        print_header "场景 3：无限滚动"
        print_info "请在接下来的 2 分钟内："
        print_info "在笔记流中快速上下滚动"
        print_step "按 Enter 开始录制..."
        read
        ;;

    search)
        TRACE_NAME="search"
        DURATION=60
        print_header "场景 4：搜索性能"
        print_info "请在接下来的 1 分钟内："
        print_info "1. 打开搜索"
        print_info "2. 快速输入 'agendada performance test'"
        print_step "按 Enter 开始录制..."
        read
        ;;

    batch)
        TRACE_NAME="batch_operations"
        DURATION=60
        print_header "场景 5：批量操作"
        print_info "请在接下来的 1 分钟内："
        print_info "1. 进入批量选择模式"
        print_info "2. 全选笔记"
        print_info "3. 执行批量删除/恢复"
        print_step "按 Enter 开始录制..."
        read
        ;;

    longrun)
        TRACE_NAME="long_running"
        DURATION=600
        print_header "场景 6：长时间运行"
        print_info "混合操作 10 分钟"
        print_step "按 Enter 开始录制..."
        read
        ;;

    *)
        print_error "未知场景: $SCENARIO"
        echo ""
        echo "可用场景："
        echo "  baseline   - 基线测量（30 秒）"
        echo "  notes      - 笔记操作（2 分钟）"
        echo "  scroll     - 无限滚动（2 分钟）"
        echo "  search     - 搜索性能（1 分钟）"
        echo "  batch      - 批量操作（1 分钟）"
        echo "  longrun    - 长时间运行（10 分钟）"
        exit 1
        ;;
esac

# 构建 trace 文件路径
TRACE_PATH="$RESULTS_DIR/${TRACE_NAME}_${TIMESTAMP}.trace"

print_info "开始录制..."
print_info "Trace 文件: $TRACE_PATH"

# 启动 Instruments
# 注意：这里使用的是命令行方式，但 Instruments 可能需要 GUI
# 如果命令行方式不可用，将打开 GUI 提示用户操作

if command -v xcrun &> /dev/null; then
    # 尝试使用 xcrun 启动 Instruments CLI
    xcrun simctl spawn booted "$BUILD_PATH/$APP_NAME" &
    APP_PID=$!

    sleep 2

    # 使用 instruments 录制（如果可用）
    if command -v instruments &> /dev/null; then
        instruments -t "$TRACE_PATH" \
            -D "$DURATION" \
            "$BUILD_PATH/$APP_NAME" \
            2>/dev/null &

        INSTRUMENTS_PID=$!

        # 等待录制完成
        print_info "录制中... (PID: $INSTRUMENTS_PID)"
        sleep $DURATION

        # 清理
        kill $INSTRUMENTS_PID 2>/dev/null || true
        kill $APP_PID 2>/dev/null || true

        print_info "录制完成！"
        print_info "打开 Trace: open \"$TRACE_PATH\""
    else
        print_error "instruments 命令不可用"
        print_info "请手动使用 Xcode Instruments 打开应用并录制"
        print_step "按 Enter 启动应用..."
        read
        "$BUILD_PATH/$APP_NAME" &
        APP_PID=$!
        print_info "应用已启动 (PID: $APP_PID)"
        print_info "请在 Instruments 中手动录制 $DURATION 秒"
        print_step "录制完成后按 Enter 结束..."
        read
        kill $APP_PID 2>/dev/null || true
    fi
else
    print_error "Xcode Command Line Tools 未安装"
    exit 1
fi

# 生成报告
print_header "测试完成"

echo ""
print_info "结果文件位置："
echo "  $RESULTS_DIR/"
echo ""
print_info "查看结果："
echo "  open \"$TRACE_PATH\""
echo ""

# 列出所有 trace 文件
print_info "所有测试结果："
ls -lh "$RESULTS_DIR/"*.trace 2>/dev/null | awk '{print "  " $9, "(" $5 ")"}' || echo "  (无)"

echo ""
print_info "下一步："
echo "  1. 在 Instruments 中打开 trace 文件"
echo "  2. 查看 Call Tree 找到热点函数"
echo "  3. 检查 Allocations 查看内存增长"
echo "  4. 导出数据用于对比"
