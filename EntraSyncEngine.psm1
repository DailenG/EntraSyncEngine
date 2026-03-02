<#
.SYNOPSIS
    The EntraSyncEngine Framework.
    A professional identity alignment and management module for Hybrid AD environments.
    
.DESCRIPTION
    Developed for MSP-scale identity migrations.
    Includes:
    - Microsoft Graph Lean Integration
    - AD Attribute Alignment (UPN, Mail, ProxyAddresses)
    - Programmatic XML Backups & CSV Manifests
    - Extensible Plugin Architecture for SSO/Writeback/Monitoring
#>

# --- Framework Configuration ---
$Global:EntraConfig = @{
    RootDir        = "C:\Temp\EntraMigration"
    LogDir         = "C:\Temp\EntraMigration\Logs"
    BackupDir      = "C:\Temp\EntraMigration\Backups"
    ExtensionDir   = "C:\Temp\EntraMigration\Extensions"
    Manifest       = "C:\Temp\EntraMigration\MigrationManifest.csv"
    RequiredSuffix = "hgor.com"
}
$Global:EntraState = @{
    LatestAuditCSV = $null
}

# --- Initialization ---
function Initialize-EntraFramework {
    foreach ($Path in @($EntraConfig.LogDir, $EntraConfig.BackupDir, $EntraConfig.ExtensionDir)) {
        if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    }
}

# --- Logging Wrapper ---
function Write-EntraLog {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
    
    if (Test-Path $Global:EntraConfig.LogDir) {
        $LogFile = Join-Path $Global:EntraConfig.LogDir "EntraSyncEngine_$(Get-Date -Format 'yyyyMMdd').log"
        Add-Content -Path $LogFile -Value $LogLine
    }
}

# --- UI Framework ---
function Write-EntraHeader {
    param([string]$Title)
    $Timestamp = Get-Date -Format "HH:mm:ss"
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " ENTRA SYNC ENGINE | $Title | $Timestamp" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "==========================================================================" -ForegroundColor Cyan
}

# --- Core Feature: Cloud Audit (Microsoft Graph) ---
function Invoke-CloudAudit {
    Write-EntraHeader "CLOUD AUDIT"
    
    # Surgical Module Check
    $Req = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users", "Microsoft.PowerShell.ConsoleGuiTools")
    foreach ($M in $Req) {
        if (-not (Get-Module -ListAvailable $M)) {
            Write-EntraLog "[*] Installing $M..." "Cyan"
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            Install-Module $M -Scope CurrentUser -AllowClobber -Force
        }
        Import-Module $M
    }

    try {
        # Ensures graph interactions remain scoped to Work/School accounts ONLY
        Connect-MgGraph -Scopes "User.Read.All" -TenantId "organizations"
        
        $DateStr = Get-Date -Format "yyyyMMdd"
        $ExportPath = Join-Path $EntraConfig.RootDir "EntraUsers_$DateStr.csv"
        
        Write-EntraLog "[*] Querying Graph for Active/Licensed users..." "Cyan"
        $Users = Get-MgUser -All -Property DisplayName, UserPrincipalName, AccountEnabled, ProxyAddresses, AssignedPlans | 
        Where-Object { $_.AccountEnabled -eq $true -and $_.AssignedPlans.Count -gt 0 }
        
        $Users | Select-Object DisplayName, UserPrincipalName, @{Name = "ProxyAddresses"; Expression = { $_.ProxyAddresses -join ";" } } | 
        Export-Csv -Path $ExportPath -NoTypeInformation
            
        $Global:EntraState.LatestAuditCSV = $ExportPath
        Write-EntraLog "[+] Exported $($Users.Count) users to $ExportPath" "Green"
    }
    catch {
        Write-EntraLog "Graph Operation Failed: $($_.Exception.Message)" "Red"
    }
    Pause
}

# --- Core Feature: AD Alignment ---
function Invoke-ADAlignment {
    Write-EntraHeader "AD ATTRIBUTE ALIGNMENT"
    
    # Pre-Flight: Suffix Check
    if ((Get-ADForest).UPNSuffixes -notcontains $EntraConfig.RequiredSuffix) {
        Write-EntraLog "[!] ERROR: Suffix '$($EntraConfig.RequiredSuffix)' not found in AD Forest." "Red"
        Pause; return
    }

    # CSV State Passing
    $CSV = $null
    if ($Global:EntraState.LatestAuditCSV -and (Test-Path $Global:EntraState.LatestAuditCSV)) {
        $PromptStr = "Path to Entra CSV [$($Global:EntraState.LatestAuditCSV)]"
        $InputCSV = Read-Host $PromptStr
        $CSV = if ([string]::IsNullOrWhiteSpace($InputCSV)) { $Global:EntraState.LatestAuditCSV } else { $InputCSV }
    }
    else {
        $CSV = Read-Host "Path to Entra CSV"
    }

    if (-not (Test-Path $CSV)) { Write-EntraLog "Invalid File." "Yellow"; Pause; return }

    # Interactive OU Selection
    Write-EntraLog "[*] Please select the target Organizational Unit (OU) for syncing from the popup window..." "Cyan"
    if (-not (Get-Module -ListAvailable "Microsoft.PowerShell.ConsoleGuiTools")) {
        Write-EntraLog "[*] Installing Microsoft.PowerShell.ConsoleGuiTools..." "Cyan"
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        Install-Module "Microsoft.PowerShell.ConsoleGuiTools" -Scope CurrentUser -AllowClobber -Force
    }
    Import-Module "Microsoft.PowerShell.ConsoleGuiTools"

    $TargetOU = Get-ADOrganizationalUnit -Filter * -Properties Description | 
    Select-Object Name, DistinguishedName, Description | 
    Out-ConsoleGridView -Title "Select the Sync Target OU" -OutputMode Single
    
    if (-not $TargetOU) {
        Write-EntraLog "[-] No OU selected. Aborting alignment." "Yellow"
        Pause; return
    }
    Write-EntraLog "[+] Selected Target Scope: $($TargetOU.DistinguishedName)" "Green"

    # Full State Backup (Safety First)
    $Bkp = Join-Path $EntraConfig.BackupDir "AD_Bkp_$(Get-Date -Format 'yyyyMMdd_HHmm').xml"
    Write-EntraLog "[*] Backing up Target OU State..." "Cyan"
    Get-ADUser -Filter * -SearchBase $TargetOU.DistinguishedName -Properties * | Export-Clixml $Bkp

    $Data = Import-Csv $CSV
    
    # Pre-flight Simulation
    Write-EntraLog "[*] Simulating AD matches against cloud export..." "Cyan"
    $MatchedUsers = @()
    $Misses = @()

    foreach ($Line in $Data) {
        $UPN = $Line.UserPrincipalName
        $Prefix = $UPN.Split("@")[0]
        
        # Advanced Match (MSP Logic) - Restricted to Enabled users within TargetOU
        $Target = Get-ADUser -Filter { (Enabled -eq $true) -and (SamAccountName -eq $Prefix -or mail -eq $UPN -or proxyAddresses -like "*$UPN*") } -SearchBase $TargetOU.DistinguishedName -Properties proxyAddresses, mail -ErrorAction SilentlyContinue
        
        if ($null -ne $Target) {
            $MatchedUsers += [PSCustomObject]@{ CloudUser = $UPN; ADUser = $Target }
        }
        else {
            $Misses += $UPN
        }
    }

    Write-EntraLog "`n--- PRE-FLIGHT SUMMARY ---" "White"
    Write-EntraLog "Active Cloud Accounts Evaluated: $($Data.Count)" "White"
    Write-EntraLog "Active AD Matches Found:         $($MatchedUsers.Count)" "Green"
    Write-EntraLog "Missing / Disabled / Unmatched:  $($Misses.Count)" "Yellow"
    Write-EntraLog "--------------------------`n" "White"

    if ($MatchedUsers.Count -eq 0) {
        Write-EntraLog "[-] No active AD matches found in the selected OU. Aborting." "Red"
        Pause; return
    }

    $Confirm = Read-Host "Type 'YES' to proceed with modifying $($MatchedUsers.Count) AD accounts"
    if ($Confirm -cne 'YES') {
        Write-EntraLog "[-] User aborted AD modifications." "Yellow"
        Pause; return
    }

    foreach ($Item in $MatchedUsers) {
        $UPN = $Item.CloudUser
        $Target = $Item.ADUser

        # Transaction Logging
        $Log = [PSCustomObject]@{
            Time       = Get-Date -Format "yyyy-MM-dd HH:mm"
            User       = $Target.SamAccountName
            DN         = $Target.DistinguishedName
            OldUPN     = $Target.UserPrincipalName
            NewUPN     = $UPN
            OldProxies = ($Target.proxyAddresses -join ";")
        }

        try {
            $Proxies = $Target.proxyAddresses | Where-Object { $_ -notlike "*$UPN*" }
            $Proxies += "SMTP:$UPN"
            
            Set-ADUser -Identity $Target.DistinguishedName -UserPrincipalName $UPN -EmailAddress $UPN -Replace @{mail = $UPN; proxyAddresses = $Proxies } -ErrorAction Stop
            $Log | Export-Csv $EntraConfig.Manifest -Append -NoTypeInformation
            Write-EntraLog "[+] Aligned: $($Target.SamAccountName)" "Green"
        }
        catch {
            Write-EntraLog "[!] Failed to align $($Target.SamAccountName). Error: $($_.Exception.Message)" "Red"
        }
    }
    Write-EntraLog "[*] AD Alignment phase complete." "Cyan"
    Pause
}

# --- Framework Feature: Extension Loader ---
function Invoke-ExtensionMenu {
    $Exts = Get-ChildItem -Path $EntraConfig.ExtensionDir -Filter "*.ps1"
    if ($Exts.Count -eq 0) { 
        Write-Host "No extensions found in $($EntraConfig.ExtensionDir)" -ForegroundColor Yellow
        Pause; return
    }

    Write-EntraHeader "EXTENSIONS & PLUGINS"
    for ($i = 0; $i -lt $Exts.Count; $i++) {
        Write-Host "$($i+1).) $($Exts[$i].BaseName)"
    }
    $Choice = Read-Host "`nSelect Extension to Run (or Q)"
    if ($Choice -match '^\d+$') {
        & $Exts[[int]$Choice - 1].FullName
    }
}

# --- Framework Feature: Rollback ---
function Invoke-Rollback {
    Write-EntraHeader "ROLLBACK ENGINE"
    if (-not (Test-Path $EntraConfig.Manifest)) { Write-EntraLog "No manifest found at $($EntraConfig.Manifest)." "Yellow"; Pause; return }
    
    $History = Import-Csv $EntraConfig.Manifest
    $User = Read-Host "SamAccountName to revert (or ALL)"
    $Queue = if ($User -eq 'ALL') { $History } else { $History | Where-Object { $_.User -eq $User } }

    if (-not $Queue) {
        Write-EntraLog "[-] No rollback operations found in queue." "Yellow"
        Pause; return
    }

    foreach ($Item in $Queue) {
        Write-EntraLog "[*] Reverting $($Item.User)..." "Cyan"
        try {
            $OldP = $Item.OldProxies -split ";"
            Set-ADUser -Identity $Item.DN -UserPrincipalName $Item.OldUPN -EmailAddress $Item.OldUPN -Replace @{mail = $Item.OldUPN; proxyAddresses = $OldP } -ErrorAction Stop
            Write-EntraLog " [+] Successfully reverted $($Item.User)" "Green"
        }
        catch {
            Write-EntraLog " [!] Failed to revert $($Item.User): $($_.Exception.Message)" "Red"
        }
    }
    Write-EntraLog "[*] Rollback phase complete." "Cyan"
    Pause
}

# --- Framework Feature: Documentation ---
function Invoke-DeploymentGuide {
    Write-EntraHeader "DEPLOYMENT WORKFLOW GUIDE"
    $GuidePath = Join-Path $PSScriptRoot "Guides\DeploymentWorkflow.md"
    if (Test-Path $GuidePath) {
        Get-Content $GuidePath | Out-Host
    }
    else {
        Write-EntraLog "[-] Guide not found at $GuidePath. Please ensure the Guides directory exists." "Red"
    }
    Pause
}

# --- Main Console Entry Point ---
function Start-EntraSyncConsole {
    Initialize-EntraFramework
    do {
        Write-EntraHeader "MAIN CONSOLE"
        Write-Host "0.) [GUIDE]  Read Deployment Workflow"
        Write-Host "1.) [CLOUD]  Run Graph Audit"
        Write-Host "2.) [LOCAL]  Align AD Attributes"
        Write-Host "3.) [VIEW]   Examine History"
        Write-Host "4.) [UNDO]   Rollback Engine"
        Write-Host "5.) [EXT]    Manage Extensions (SSO/Writeback)"
        Write-Host "Q.) [EXIT]"
        
        $Choice = Read-Host "`nSelection"
        switch ($Choice) {
            '0' { Invoke-DeploymentGuide }
            '1' { Invoke-CloudAudit }
            '2' { Invoke-ADAlignment }
            '3' { if (Test-Path $EntraConfig.Manifest) { Import-Csv $EntraConfig.Manifest | Out-GridView -Title "History" } }
            '4' { Invoke-Rollback }
            '5' { Invoke-ExtensionMenu }
        }
    } while ($Choice -ne 'Q')
}

Export-ModuleMember -Function Start-EntraSyncConsole