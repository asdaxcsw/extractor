# 使用GitHub Actions在线构建APK（无需Docker）

由于你的Windows系统没有安装Docker，我推荐使用GitHub Actions在线构建。这个方法完全免费，不需要在本地安装任何工具。

## 步骤说明

### 1. 创建GitHub仓库

1. 访问 https://github.com/new
2. 输入仓库名称，例如：`douyin-sessionid-extractor`
3. 选择 Public 或 Private
4. 点击 "Create repository"

### 2. 上传项目到GitHub

打开PowerShell，运行以下命令：

```powershell
cd C:\Users\Administrator\.cursor\projects\empty-window

# 初始化Git仓库
git init

# 添加所有文件
git add .

# 提交
git commit -m "Initial commit"

# 添加远程仓库（替换YOUR_USERNAME和YOUR_REPO为你的实际信息）
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# 推送到GitHub
git branch -M main
git push -u origin main
```

### 3. 触发自动构建

推送完成后：

1. 访问你的GitHub仓库页面
2. 点击顶部的 "Actions" 标签
3. 你会看到 "Build Android APK" 工作流正在运行
4. 等待构建完成（大约15-30分钟）

### 4. 下载APK

构建完成后：

1. 在Actions页面，点击最新的构建记录
2. 向下滚动到 "Artifacts" 部分
3. 点击 "android-apk" 下载ZIP文件
4. 解压ZIP文件，里面就是APK文件

### 5. 安装到手机

1. 将APK文件传输到Android设备
2. 在设备上启用"允许安装未知来源应用"
3. 点击APK文件安装
4. 打开应用，授予ROOT权限
5. 点击"提取SessionID"按钮

## 手动触发构建

如果你修改了代码，想重新构建：

1. 访问GitHub仓库的Actions页面
2. 点击左侧的 "Build Android APK"
3. 点击右侧的 "Run workflow" 按钮
4. 点击绿色的 "Run workflow" 确认
5. 等待构建完成并下载新的APK

## 如果你还是想用Docker

如果你想在本地构建，需要先安装Docker Desktop：

1. 下载：https://www.docker.com/products/docker-desktop
2. 安装并重启电脑
3. 启动Docker Desktop
4. 然后运行：

```powershell
cd C:\Users\Administrator\.cursor\projects\empty-window
docker run --rm -v "%cd%":/home/user/hostcwd kivy/buildozer android debug
```

## 常见问题

**Q: GitHub Actions构建失败怎么办？**
A: 点击失败的构建记录，查看详细日志，通常是依赖下载问题，重新运行即可。

**Q: 我没有GitHub账号怎么办？**
A: 访问 https://github.com/signup 免费注册一个。

**Q: 构建的APK在哪里？**
A: 在Actions页面的构建记录中，"Artifacts"部分可以下载。

**Q: 可以构建release版本吗？**
A: 可以，修改 `.github/workflows/build.yml` 文件，将 `buildozer android debug` 改为 `buildozer android release`，但需要配置签名密钥。

## 优势

- 完全免费
- 不占用本地资源
- 不需要安装Docker
- 构建环境标准化
- 可以随时重新构建

现在你可以按照上面的步骤，将项目上传到GitHub，然后等待自动构建完成！
