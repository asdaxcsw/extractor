# APK构建指南

## 方法一：使用Docker（推荐，适用于Windows/Mac/Linux）

这是最简单的方法，不需要配置复杂的Android开发环境。

### 步骤：

1. 安装Docker Desktop
   - Windows: 从 https://www.docker.com/products/docker-desktop 下载安装
   - 安装后启动Docker Desktop

2. 打开PowerShell或命令提示符，进入项目目录：

```bash
cd C:\Users\Administrator\.cursor\projects\empty-window
```

3. 使用Docker构建APK：

```bash
docker run --rm -v "%cd%":/home/user/hostcwd kivy/buildozer android debug
```

4. 构建完成后，APK文件位于 `bin` 目录下：
   - `bin/douyinsessionid-1.0-arm64-v8a-debug.apk`
   - `bin/douyinsessionid-1.0-armeabi-v7a-debug.apk`

### 注意事项：
- 首次构建会下载Android SDK/NDK，需要较长时间（30分钟-2小时）
- 需要稳定的网络连接
- 确保有足够的磁盘空间（至少10GB）

---

## 方法二：使用Linux虚拟机或WSL2

### 在Ubuntu/Debian上安装依赖：

```bash
# 更新系统
sudo apt update
sudo apt upgrade -y

# 安装Python和pip
sudo apt install -y python3 python3-pip python3-venv

# 安装Buildozer依赖
sudo apt install -y git zip unzip openjdk-17-jdk autoconf libtool pkg-config zlib1g-dev libncurses5-dev libncursesw5-dev libtinfo5 cmake libffi-dev libssl-dev

# 安装Buildozer
pip3 install --user buildozer

# 安装Cython
pip3 install --user cython
```

### 构建APK：

```bash
# 进入项目目录
cd /path/to/project

# 初始化buildozer（如果是首次使用）
buildozer init

# 构建debug版本APK
buildozer android debug

# 或构建release版本（需要签名）
buildozer android release
```

### 构建完成后：
APK文件在 `bin/` 目录下

---

## 方法三：使用在线构建服务

如果本地构建困难，可以使用在线服务：

### 使用GitHub Actions自动构建

创建 `.github/workflows/build.yml`：

```yaml
name: Build APK

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.10'
    
    - name: Install dependencies
      run: |
        pip install buildozer cython
        sudo apt update
        sudo apt install -y git zip unzip openjdk-17-jdk autoconf libtool pkg-config zlib1g-dev libncurses5-dev libncursesw5-dev libtinfo5 cmake libffi-dev libssl-dev
    
    - name: Build APK
      run: buildozer android debug
    
    - name: Upload APK
      uses: actions/upload-artifact@v3
      with:
        name: apk
        path: bin/*.apk
```

推送到GitHub后，在Actions标签页下载构建好的APK。

---

## 常见问题

### 1. 构建失败：找不到SDK/NDK

确保 `buildozer.spec` 中的版本号正确：

```ini
android.api = 31
android.minapi = 21
android.ndk = 25b
```

### 2. 构建时间过长

首次构建需要下载大量依赖，这是正常的。后续构建会快很多。

### 3. 内存不足

Docker构建时可以增加内存限制：

```bash
docker run --rm -v "%cd%":/home/user/hostcwd --memory=4g kivy/buildozer android debug
```

### 4. 权限问题（Linux）

如果生成的文件权限不对：

```bash
sudo chown -R $USER:$USER bin/
```

---

## 签名APK（用于发布）

生成release版本需要签名：

1. 生成密钥：

```bash
keytool -genkey -v -keystore my-release-key.keystore -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000
```

2. 在 `buildozer.spec` 中配置：

```ini
[app]
android.release_artifact = apk

[buildozer]
android.keystore = my-release-key.keystore
android.keystore_alias = my-key-alias
```

3. 构建release版本：

```bash
buildozer android release
```

---

## 快速开始（推荐）

如果你使用Windows，最简单的方法是：

1. 安装Docker Desktop
2. 运行以下命令：

```powershell
cd C:\Users\Administrator\.cursor\projects\empty-window
docker run --rm -v "%cd%":/home/user/hostcwd kivy/buildozer android debug
```

3. 等待构建完成（首次需要30-60分钟）
4. 在 `bin` 目录找到APK文件
5. 将APK传输到Android设备安装

---

## 测试APK

1. 在Android设备上启用"未知来源"安装
2. 将APK传输到设备
3. 点击安装
4. 打开应用，授予ROOT权限
5. 点击"提取SessionID"按钮测试
