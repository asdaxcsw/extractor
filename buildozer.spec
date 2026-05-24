[app]

title = TestApp
package.name = testapp
package.domain = com.test

source.dir = .
source.include_exts = py

version = 1.0

requirements = python3,kivy

android.archs = armeabi-v7a

android.permissions = INTERNET

android.api = 33
android.minapi = 21
android.ndk = 25b

orientation = portrait

log_level = 2

[buildozer]

log_level = 2
