# 抖音SessionID提取器

这是一个用于提取抖音应用中sessionid_ss参数的Android应用。

## 功能特性

- 自动读取抖音应用数据目录中的cookie文件
- 提取并显示sessionid_ss参数
- 支持一键复制到剪贴板
- 需要ROOT权限

## 系统要求

- Android 5.0 (API 21) 或更高版本
- 已ROOT的设备
- 已安装抖音应用

## 使用方法

### 在Android设备上使用

1. 确保设备已获取ROOT权限
2. 安装生成的APK文件
3. 打开应用
4. 点击"提取SessionID"按钮
5. 授予ROOT权限（如果弹出提示）
6. 查看提取结果
7. 点击"复制到剪贴板"复制结果

### 在电脑上测试

```bash
python main.py
```

注意：在电脑上运行只会显示测试数据，需要在Android设备上运行才能获取真实数据。

## 构建APK

### 使用Buildozer（Linux/Mac）

1. 安装Buildozer：
```bash
pip install buildozer
```

2. 安装Android SDK和NDK依赖

3. 构建APK：
```bash
buildozer android debug
```

4. APK文件将生成在 `bin/` 目录下

### 使用Docker（推荐）

```bash
docker run --rm -v "$PWD":/app kivy/buildozer android debug
```

## 技术栈

- Python 3
- Kivy - 跨平台GUI框架
- Pyjnius - Python与Java交互
- Android SDK/NDK

## 工作原理

应用通过以下步骤提取sessionid_ss：

1. 使用ROOT权限访问 `/data/data/com.ss.android.ugc.aweme.mobile/files/keva/repo/aweme_feed_cookie_store/` 目录
2. 读取目录中的所有文件
3. 使用正则表达式匹配 `sessionid_ss=` 参数
4. 提取并显示所有找到的sessionid值

## 注意事项

- 本应用需要ROOT权限才能访问其他应用的数据目录
- 请确保已安装并登录抖音应用
- 提取的sessionid_ss是敏感信息，请妥善保管
- 仅供学习和研究使用

## 许可证

MIT License

## 免责声明

本工具仅供学习和研究使用，使用者需遵守相关法律法规和抖音的服务条款。开发者不对使用本工具造成的任何后果负责。
