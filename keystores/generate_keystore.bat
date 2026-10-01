@echo off
set KEYSTORE_PATH=%~dp0release.keystore
set KEYTOOL_PATH="C:\Program Files\Java\jdk-26.0.2\bin\keytool.exe"

if not exist %KEYTOOL_PATH% (
    set KEYTOOL_PATH=keytool
)

if exist "%KEYSTORE_PATH%" del /f /q "%KEYSTORE_PATH%"

echo Generating release keystore at %KEYSTORE_PATH%...

%KEYTOOL_PATH% -genkeypair -v ^
  -keystore "%KEYSTORE_PATH%" ^
  -alias genericreleasekey ^
  -keyalg RSA ^
  -keysize 2048 ^
  -validity 10000 ^
  -storetype PKCS12 ^
  -storepass android ^
  -keypass android ^
  -dname "CN=IdleArcade, OU=Development, O=GameStudio, L=City, ST=State, C=US"

if %ERRORLEVEL% EQU 0 (
    echo Keystore generated successfully at %KEYSTORE_PATH%
) else (
    echo Error generating keystore. Exit code: %ERRORLEVEL%
)
