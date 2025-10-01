@echo off
echo 正在创建Hushie应用的发布签名keystore...
echo.
echo 请注意：
echo 1. 密码至少需要6个字符
echo 2. 请妥善保管keystore文件和密码
echo 3. 丢失keystore将无法更新已发布的应用
echo.

keytool -genkey -v -keystore hushie-release-key.keystore -alias hushie -keyalg RSA -keysize 2048 -validity 10000

echo.
echo keystore创建完成！
echo 文件位置: %cd%\hushie-release-key.keystore
echo.
pause