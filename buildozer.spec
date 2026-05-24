[app]

# 应用标题
title = 抖音SessionID提取器

# 包名
package.name = douyinsessionid

# 包域名
package.domain = com.extractor

# 源代码目录
source.dir = .

# 源文件包含
source.include_exts = py,png,jpg,kv,atlas

# 应用版本
version = 1.0

# 应用需求
requirements = python3,kivy==2.3.0,android

# 支持的架构
android.archs = arm64-v8a,armeabi-v7a

# Android权限
android.permissions = INTERNET,READ_EXTERNAL_STORAGE,WRITE_EXTERNAL_STORAGE,ACCESS_SUPERUSER

# Android API版本
android.api = 31
android.minapi = 21
android.ndk = 25b

# 应用图标
#icon.filename = %(source.dir)s/icon.png

# 启动画面
#presplash.filename = %(source.dir)s/presplash.png

# 方向
orientation = portrait

# 全屏
fullscreen = 0

# Android入口点
android.entrypoint = org.kivy.android.PythonActivity

# Android应用主题
android.apptheme = "@android:style/Theme.NoTitleBar"

# 日志级别
log_level = 2

# 警告级别
warn_on_root = 1

[buildozer]

# 日志级别
log_level = 2

# 警告
warn_on_root = 1
