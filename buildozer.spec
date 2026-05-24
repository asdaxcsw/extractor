[app]

title = DouyinSessionID
package.name = douyinsessionid
package.domain = com.extractor

source.dir = .
source.include_exts = py,png,jpg,kv,atlas

version = 1.0

requirements = python3,kivy==2.1.0

android.archs = arm64-v8a

android.permissions = INTERNET,READ_EXTERNAL_STORAGE,WRITE_EXTERNAL_STORAGE

android.api = 31
android.minapi = 21
android.ndk = 23b
android.accept_sdk_license = True
android.skip_update = False

orientation = portrait
fullscreen = 0

log_level = 2

[buildozer]

log_level = 2
warn_on_root = 1
