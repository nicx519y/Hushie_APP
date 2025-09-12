@echo off
echo ========================================
echo    Android 应用签名哈希获取工具
echo ========================================
echo.

echo 方法1: 从已安装的应用获取签名哈希
echo ----------------------------------------
echo 请确保应用已安装并运行以下命令:
echo adb logcat -c ^&^& adb logcat ^| findstr "SignatureVerification"
echo.
echo 然后启动应用，查看日志中的 "当前签名哈希" 输出
echo.

echo 方法2: 从 keystore 文件获取签名哈希
echo ----------------------------------------
set /p keystore_path=请输入 keystore 文件路径: 
set /p key_alias=请输入 key alias: 

if "%keystore_path%"=="" (
    echo 错误: keystore 路径不能为空
    pause
    exit /b 1
)

if "%key_alias%"=="" (
    echo 错误: key alias 不能为空
    pause
    exit /b 1
)

echo.
echo 正在获取签名信息...
echo ----------------------------------------
keytool -list -v -keystore "%keystore_path%" -alias "%key_alias%"

echo.
echo ========================================
echo 使用说明:
echo 1. 找到输出中的 "SHA256:" 行
echo 2. 复制冒号后的哈希值（去掉冒号和空格）
echo 3. 将哈希值更新到 SignatureVerificationService.kt 中
echo ========================================
echo.
pause