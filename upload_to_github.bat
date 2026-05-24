@echo off
chcp 65001 >nul
echo ========================================
echo Git 安装和项目上传助手
echo ========================================
echo.

echo 检查Git是否已安装...
git --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [✓] Git已安装
    git --version
    echo.
    goto :upload
)

echo [!] Git未安装
echo.
echo ========================================
echo 请按照以下步骤安装Git:
echo ========================================
echo.
echo 1. 访问 Git 官网下载页面:
echo    https://git-scm.com/download/win
echo.
echo 2. 下载 "64-bit Git for Windows Setup"
echo.
echo 3. 运行安装程序，使用默认设置即可
echo    (一路点击 "Next" 即可)
echo.
echo 4. 安装完成后，关闭并重新打开 PowerShell
echo.
echo 5. 再次运行本脚本
echo.
echo ========================================
echo 正在为你打开下载页面...
echo ========================================
start https://git-scm.com/download/win
echo.
pause
exit /b 1

:upload
echo ========================================
echo 准备上传项目到GitHub
echo ========================================
echo.
echo 请确保你已经:
echo 1. 在 GitHub 上创建了仓库
echo 2. 记下了仓库地址 (例如: https://github.com/用户名/仓库名.git)
echo.
set /p repo_url="请输入你的GitHub仓库地址: "

if "%repo_url%"=="" (
    echo [错误] 仓库地址不能为空
    pause
    exit /b 1
)

echo.
echo 正在初始化Git仓库...
git init

echo.
echo 正在添加文件...
git add .

echo.
echo 正在提交...
git commit -m "Initial commit: 抖音SessionID提取器"

echo.
echo 正在添加远程仓库...
git remote add origin %repo_url%

echo.
echo 正在推送到GitHub...
git branch -M main
git push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo [✓] 上传成功!
    echo ========================================
    echo.
    echo 下一步:
    echo 1. 访问你的GitHub仓库页面
    echo 2. 点击 "Actions" 标签
    echo 3. 等待自动构建完成 (15-30分钟)
    echo 4. 在 "Artifacts" 部分下载APK
    echo.
    echo 正在打开你的GitHub仓库...
    start %repo_url:.git=%
) else (
    echo.
    echo ========================================
    echo [✗] 上传失败
    echo ========================================
    echo.
    echo 可能的原因:
    echo - 仓库地址错误
    echo - 需要登录GitHub (首次使用需要配置凭据)
    echo - 网络连接问题
    echo.
    echo 如果需要配置GitHub凭据，请运行:
    echo git config --global user.name "你的用户名"
    echo git config --global user.email "你的邮箱"
    echo.
)

pause
