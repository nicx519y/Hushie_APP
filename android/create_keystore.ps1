# Hushie App Release Keystore Creation Script

Write-Host "Creating Hushie app release keystore..." -ForegroundColor Green
Write-Host ""
Write-Host "Important Notes:" -ForegroundColor Yellow
Write-Host "1. Password must be at least 6 characters" -ForegroundColor White
Write-Host "2. Keep keystore file and password safe" -ForegroundColor White
Write-Host "3. Losing keystore will prevent app updates" -ForegroundColor White
Write-Host ""

# Execute keytool command
keytool -genkey -v -keystore hushie-release-key.keystore -alias hushie -keyalg RSA -keysize 2048 -validity 10000

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Keystore created successfully!" -ForegroundColor Green
    Write-Host "File location: $(Get-Location)\hushie-release-key.keystore" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "Keystore creation failed, please check input" -ForegroundColor Red
}

Write-Host "Press any key to continue..."
Read-Host