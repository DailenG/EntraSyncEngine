<#
.SYNOPSIS
    Publishes the EntraSyncEngine module to the PowerShell Gallery.

.PARAMETER ApiKey
    The NuGet API Key for the PowerShell Gallery. Required.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'
$moduleName = "EntraSyncEngine"
$modulePath = $PSScriptRoot
$stagingPath = Join-Path -Path $modulePath -ChildPath "Staging"
$stagingModulePath = Join-Path -Path $stagingPath -ChildPath $moduleName

Write-Host "Starting publication process for '$moduleName'..." -ForegroundColor Cyan

try {
    Write-Host "Creating staging directory at '$stagingModulePath'..." -ForegroundColor Cyan
    if (Test-Path -Path $stagingPath) {
        Remove-Item -Path $stagingPath -Recurse -Force
    }
    New-Item -Path $stagingModulePath -ItemType Directory -Force | Out-Null

    Write-Host "Copying module files to staging..." -ForegroundColor Cyan
    # Explicitly staging required files to keep gallery payloads clean (excluding .git, etc)
    $itemsToCopy = @(
        "$moduleName.psd1",
        "$moduleName.psm1",
        "README.md",
        "agent.md",
        "Extensions",
        "Guides"
    )

    foreach ($item in $itemsToCopy) {
        $sourcePath = Join-Path -Path $modulePath -ChildPath $item
        if (Test-Path -Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $stagingModulePath -Recurse -Force
        }
        else {
            Write-Warning "Item '$item' not found, skipping..."
        }
    }

    $manifestData = Import-PowerShellDataFile -Path (Join-Path $stagingModulePath "$moduleName.psd1")
    $versionString = $manifestData.ModuleVersion
    if ($manifestData.PrivateData.PSData.Prerelease) {
        $versionString += "-" + $manifestData.PrivateData.PSData.Prerelease
    }
    
    Write-Host "Publishing $moduleName $versionString to PowerShell Gallery..." -ForegroundColor Cyan
    Publish-Module -Path $stagingModulePath -NuGetApiKey $ApiKey
    
    Write-Host "Cleaning up staging directory..." -ForegroundColor Cyan
    Remove-Item -Path $stagingPath -Recurse -Force

    Write-Host "Successfully published $moduleName!" -ForegroundColor Green
}
catch {
    Write-Error "Publishing failed: $_"
}
