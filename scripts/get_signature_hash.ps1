# Android App Signature Hash Tool (PowerShell Version)
# 自动获取项目签名信息，无需手动输入路径

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Android App Signature Hash Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 硬编码的keystore路径和配置
$projectRoot = Split-Path -Parent $PSScriptRoot
$keystorePath = Join-Path $projectRoot "android\upload-keystore.jks"
$keyAlias = "release"
$debugKeystorePath = "$env:USERPROFILE\.android\debug.keystore"
$debugKeyAlias = "androiddebugkey"

Write-Host "Method 1: Get signature hash from installed app" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "Make sure the app is installed and run:"
Write-Host "adb logcat -c && adb logcat | Select-String 'SignatureVerification'" -ForegroundColor Green
Write-Host ""
Write-Host "Then launch the app and check the log output for 'Current signature hash'"
Write-Host ""

Write-Host "Method 2: Get signature hash from keystore files" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow

# 检查Release keystore
Write-Host "Checking Release Keystore..." -ForegroundColor Magenta
if (Test-Path $keystorePath) {
    Write-Host "Found Release keystore: $keystorePath" -ForegroundColor Green
    Write-Host "Key alias: $keyAlias" -ForegroundColor Green
    Write-Host ""
    Write-Host "Getting Release signature information..." -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    
    try {
        & keytool -list -v -keystore $keystorePath -alias $keyAlias -storepass "hushie2024" -keypass "hushie2024"
        Write-Host ""
    }
    catch {
        Write-Host "Error getting Release signature: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Trying without hardcoded passwords..." -ForegroundColor Yellow
        & keytool -list -v -keystore $keystorePath -alias $keyAlias
        Write-Host ""
    }
} else {
    Write-Host "Release keystore not found at: $keystorePath" -ForegroundColor Red
    Write-Host ""
}

# 检查Debug keystore
Write-Host "Checking Debug Keystore..." -ForegroundColor Magenta
if (Test-Path $debugKeystorePath) {
    Write-Host "Found Debug keystore: $debugKeystorePath" -ForegroundColor Green
    Write-Host "Key alias: $debugKeyAlias" -ForegroundColor Green
    Write-Host ""
    Write-Host "Getting Debug signature information..." -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    
    try {
        & keytool -list -v -keystore $debugKeystorePath -alias $debugKeyAlias -storepass "android" -keypass "android"
        Write-Host ""
    }
    catch {
        Write-Host "Error getting Debug signature: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
    }
} else {
    Write-Host "Debug keystore not found at: $debugKeystorePath" -ForegroundColor Red
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. Find the 'SHA1:' and 'SHA-256:' lines in the output above" -ForegroundColor White
Write-Host "2. Copy the hash values (they are already formatted correctly)" -ForegroundColor White
Write-Host "3. Use Release keystore hash for production builds" -ForegroundColor White
Write-Host "4. Use Debug keystore hash for development/testing" -ForegroundColor White
Write-Host "5. Update the hash value in your app's signature verification service" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")