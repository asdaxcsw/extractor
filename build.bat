@echo off
chcp 65001 >nul
echo ========================================
echo 抖音SessionID提取器 - APK构建脚本
echo ========================================
echo.

echo 检查Docker是否安装...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未检测到Docker
    echo.
    echo 请先安装Docker Desktop:
    echo https://www.docker.com/products/docker-desktop
    echo.
    pause
    exit /b 1
)

echo [✓] Docker已安装
echo.

echo 检查Docker是否运行...
docker ps >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Docker未运行
    echo.
    echo 请启动Docker Desktop后重试
    echo.
    pause
    exit /b 1
)

echo [✓] Docker正在运行
echo.

echo ========================================
echo 开始构建APK...
echo ========================================
echo.
echo 注意事项:
echo - 首次构建需要下载Android SDK/NDK (约2-5GB)
echo - 预计耗时: 30分钟 - 2小时
echo - 请保持网络连接稳定
echo - 后续构建会快很多
echo.

set /p confirm="是否继续? (Y/N): "
if /i not "%confirm%"=="Y" (
    echo 已取消构建
    pause
    exit /b 0
)

echo.
echo 正在构建，请耐心等待...
echo.

docker run --rm -v "%cd%":/home/user/hostcwd kivy/buildozer android debug

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo [✓] 构建成功!
    echo ========================================
    echo.
    echo APK文件位置: bin\
    echo.
    dir /b bin\*.apk 2>nul
    echo.
    echo 下一步:
    echo 1. 将APK文件传输到Android设备
    echo 2. 在设备上启用"允许安装未知来源应用"
    echo 3. 点击APK文件安装
    echo 4. 确保设备已ROOT
    echo 5. 打开应用并授予ROOT权限
    echo.
) else (
    echo.
    echo ========================================
    echo [✗] 构建失败
    echo ========================================
    echo.
    echo 可能的原因:
    echo - 网络连接问题
    echo - 磁盘空间不足
    echo - Docker配置问题
    echo.
    echo 请检查错误信息并重试
    echo.
)

pause
