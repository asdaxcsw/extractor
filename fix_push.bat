@echo off
chcp 65001 >nul
echo ========================================
echo GitHub推送问题诊断和修复工具
echo ========================================
echo.

cd /d C:\Users\Administrator\.cursor\projects\empty-window

echo [1/5] 检查Git配置...
git config --list | findstr "remote.origin.url"
echo.

echo [2/5] 测试GitHub连接...
ping -n 2 github.com
echo.

echo [3/5] 尝试推送到GitHub...
echo.
git push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo [✓] 推送成功!
    echo ========================================
    echo.
    echo 下一步:
    echo 1. 访问 https://github.com/asdaxcsw/extractor
    echo 2. 点击 "Actions" 标签
    echo 3. 等待自动构建完成 (15-30分钟)
    echo 4. 下载APK文件
    echo.
    start https://github.com/asdaxcsw/extractor
    pause
    exit /b 0
)

echo.
echo ========================================
echo [✗] 推送失败，尝试其他方案...
echo ========================================
echo.

echo [4/5] 尝试增加超时时间...
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999
echo 配置已更新，重试推送...
echo.
git push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo [✓] 推送成功!
    echo ========================================
    echo.
    start https://github.com/asdaxcsw/extractor
    pause
    exit /b 0
)

echo.
echo ========================================
echo [!] 仍然失败，需要手动处理
echo ========================================
echo.
echo 可能的原因:
echo 1. 网络连接不稳定
echo 2. 需要配置代理
echo 3. 防火墙阻止连接
echo.
echo 建议的解决方案:
echo.
echo 方案A: 如果你使用代理/VPN
echo   运行以下命令（替换为你的代理地址）:
echo   git config --global http.proxy http://127.0.0.1:7890
echo   git config --global https.proxy http://127.0.0.1:7890
echo   git push -u origin main
echo.
echo 方案B: 使用SSH代替HTTPS
echo   1. 生成SSH密钥: ssh-keygen -t ed25519
echo   2. 添加公钥到GitHub: https://github.com/settings/keys
echo   3. 更改远程地址: git remote set-url origin git@github.com:asdaxcsw/extractor.git
echo   4. 重新推送: git push -u origin main
echo.
echo 方案C: 使用GitHub Desktop (最简单)
echo   1. 下载: https://desktop.github.com/
echo   2. 安装并登录
echo   3. 添加本地仓库
echo   4. 点击 "Publish repository"
echo.
echo 正在打开GitHub Desktop下载页面...
start https://desktop.github.com/
echo.
echo 详细说明请查看: 解决推送问题.md
echo.
pause
