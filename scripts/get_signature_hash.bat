@echo off
chcp 65001 >nul
echo ========================================
echo    Android App Signature Hash Tool
echo ========================================
echo.

echo Method 1: Get signature hash from installed app
echo ----------------------------------------
echo Make sure the app is installed and run:
echo adb logcat -c ^&^& adb logcat ^| findstr "SignatureVerification"
echo.
echo Then launch the app and check the log output for "Current signature hash"
echo.

echo Method 2: Get signature hash from keystore file
echo ----------------------------------------
set /p keystore_path=Enter keystore file path: 
set /p key_alias=Enter key alias: 

if "%keystore_path%"=="" (
    echo Error: keystore path cannot be empty
    pause
    exit /b 1
)

if "%key_alias%"=="" (
    echo Error: key alias cannot be empty
    pause
    exit /b 1
)

echo.
echo Getting signature information...
echo ----------------------------------------
keytool -list -v -keystore "%keystore_path%" -alias "%key_alias%"

echo.
echo ========================================
echo Instructions:
echo 1. Find the "SHA256:" line in the output
echo 2. Copy the hash value after the colon (remove colons and spaces)
echo 3. Update the hash value in SignatureVerificationService.kt
echo ========================================
echo.
pause