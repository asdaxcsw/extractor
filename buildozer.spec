[app]

title = DouyinSessionID
package.name = douyinsessionid
package.domain = com.extractor

source.dir = .
source.include_exts = py,png,jpg,kv,atlas

version = 1.0

requirements = python3,kivy==2.2.1,android,pyjnius

android.archs = arm64-v8a

android.permissions = INTERNET,READ_EXTERNAL_STORAGE,WRITE_EXTERNAL_STORAGE

android.api = 33
android.minapi = 21
android.ndk = 25b
android.accept_sdk_license = True

orientation = portrait
fullscreen = 0

android.entrypoint = org.kivy.android.PythonActivity
android.apptheme = "@android:style/Theme.NoTitleBar"

log_level = 2
warn_on_root = 1

[buildozer]

log_level = 2
warn_on_root = 1
