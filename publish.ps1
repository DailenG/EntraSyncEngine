# publish.ps1
# Automates testing and publishing of EntraSyncEngine to the PSGallery.

$ModulePath = Join-Path $PSScriptRoot "EntraSyncEngine.psd1"

Write-Host "[*] Auditing Module Manifest..." -ForegroundColor Cyan
Test-ModuleManifest -Path $ModulePath

Write-Host "[?] Provide your PowerShell Gallery API Key to proceed with Publish-Module (or hit Enter to abort):" -ForegroundColor Yellow
$ApiKey = Read-Host

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host "[-] Aborting publish." -ForegroundColor Yellow
    exit
}

Write-Host "[*] Publishing EntraSyncEngine to PSGallery..." -ForegroundColor Cyan
try {
    Publish-Module -Path $PSScriptRoot -NuGetApiKey $ApiKey -Verbose -ErrorAction Stop
    Write-Host "[+] Successfully Published EntraSyncEngine!" -ForegroundColor Green
}
catch {
    Write-Host "[!] Publish Failed: $($_.Exception.Message)" -ForegroundColor Red
}
