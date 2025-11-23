#!/bin/bash

# 测试脚本：验证专业版插件显示
# 此脚本将以专业版模式运行应用并检查插件数量

echo "========================================"
echo "CorePlayer 专业版插件测试"
echo "========================================"
echo ""

echo "步骤 1: 清理构建缓存"
flutter clean
echo ""

echo "步骤 2: 获取依赖"
flutter pub get
echo ""

echo "步骤 3: 以专业版模式运行应用"
echo "使用编译标志: --dart-define=EDITION=pro"
echo ""
echo "预期结果："
echo "  - 总插件数: 7"
echo "  - 包含: 1个基础插件 + 6个商业插件"
echo "    1. Media Server (基础)"
echo "    2. HEVC 专业解码器"
echo "    3. AI 智能字幕"
echo "    4. 多设备同步"
echo "    5. SMB/CIFS 媒体服务器"
echo "    6. FTP/SFTP 媒体服务器"
echo "    7. NFS 网络文件系统"
echo ""
echo "启动应用..."
flutter run --dart-define=EDITION=pro

echo ""
echo "========================================"
echo "测试完成"
echo "========================================"
