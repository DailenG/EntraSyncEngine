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
        # -Global prevents the imported module from being tracked as a child of EntraSyncEngine
        Import-Module $M -Global
    }

    try {
        # Ensures graph interactions remain scoped to Work/School accounts ONLY and suppresses the welcome string
        Connect-MgGraph -Scopes "User.Read.All" -TenantId "organizations" -NoWelcome
        
        $DateStr = Get-Date -Format "yyyyMMdd"
        $ExportPath = Join-Path $EntraConfig.RootDir "EntraUsers_$DateStr.csv"
        
        Write-EntraLog "[*] Querying Graph for Active/Licensed users..." "Cyan"
        # Explicit PageSize and ConsistencyLevel prevents the Graph SDK from arbitrarily truncating complex property queries
        $Users = Get-MgUser -All -PageSize 500 -ConsistencyLevel eventual -Property DisplayName, UserPrincipalName, AccountEnabled, ProxyAddresses, AssignedPlans | 
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
    $ActiveMatches = @()
    $DisabledMatches = @()
    $Misses = @()

    foreach ($Line in $Data) {
        $UPN = $Line.UserPrincipalName
        $Prefix = $UPN.Split("@")[0]
        
        # Advanced Match (MSP Logic) - Search for both enabled and disabled accounts
        $Target = Get-ADUser -Filter { SamAccountName -eq $Prefix -or mail -eq $UPN -or proxyAddresses -like "*$UPN*" } -SearchBase $TargetOU.DistinguishedName -Properties proxyAddresses, mail, Enabled -ErrorAction SilentlyContinue
        
        if ($null -ne $Target) {
            $MatchObj = [PSCustomObject]@{ CloudUser = $UPN; ADUser = $Target }
            if ($Target.Enabled) {
                $ActiveMatches += $MatchObj
            }
            else {
                $DisabledMatches += $MatchObj
            }
        }
        else {
            $Misses += $UPN
        }
    }

    $TotalMatches = $ActiveMatches.Count + $DisabledMatches.Count

    Write-EntraLog "`n--- PRE-FLIGHT SUMMARY ---" "White"
    Write-EntraLog "Active Cloud Accounts Evaluated: $($Data.Count)" "White"
    Write-EntraLog "Active AD Matches Found:         $($ActiveMatches.Count)" "Green"
    Write-EntraLog "Disabled AD Matches Found:       $($DisabledMatches.Count)" "DarkYellow"
    Write-EntraLog "Missing / Unmatched:             $($Misses.Count)" "Yellow"
    Write-EntraLog "--------------------------`n" "White"
    
    Write-EntraLog "--- ALIGNMENT OVERVIEW ---" "Cyan"
    Write-EntraLog "To ensure a perfect 'Soft-Match' when Microsoft Entra Connect Service is installed," "White"
    Write-EntraLog "this engine will now surgically modify the local Active Directory accounts to match the Cloud." "White"
    Write-EntraLog "For every matched account, the following AD attributes will be OVERWRITTEN:" "Yellow"
    Write-EntraLog "  1. UserPrincipalName -> Replaced with the exact Cloud UPN." "White"
    Write-EntraLog "  2. mail -> Replaced with the exact Cloud UPN." "White"
    Write-EntraLog "  3. proxyAddresses -> The Cloud UPN will be injected as the primary SMTP address.`n" "White"
    
    Write-EntraLog "--- ENTRA CONNECT REQUIREMENT ---" "Cyan"
    Write-EntraLog "When you install Entra Connect Sync (Phase 2), you MUST configure it to match using the" "White"
    Write-EntraLog "UserPrincipalName or Mail attribute. Do not rely on ms-DS-ConsistencyGuid for the initial sync.`n" "White"

    if ($Misses.Count -gt 0) {
        Write-EntraLog "[!] WARNING: $($Misses.Count) Cloud Accounts could not be matched to ANY AD account." "Red"
        Write-EntraLog "    If you proceed with installing Entra Connect Sync while these accounts are unmatched," "Yellow"
        Write-EntraLog "    Entra Connect may assume they are deleted on-premise and may DISABLE them in the cloud." "Yellow"
        Write-EntraLog "    Please review the missing accounts manually before syncing.`n" "White"
    }

    if ($DisabledMatches.Count -gt 0) {
        Write-EntraLog "[!] CRITICAL WARNING: $($DisabledMatches.Count) Active Cloud Accounts matched CLOSED/DISABLED AD Accounts." "Red"
        Write-EntraLog "    When Entra Connect Sync runs, it bridges 'accountEnabled' states." "Red"
        Write-EntraLog "    Because the AD account is disabled, Entra Connect WILL INSTANTLY DISABLE the cloud mailbox." "Red"
        Write-EntraLog "    If these are retained mailboxes (e.g., terminated employees), you must exclude them from the sync scope OR leave them unmatched.`n" "White"
        
        Write-EntraLog "[?] If you understand and wish to proceed, type 'OK' or solve this equation to five decimals: √π = ?" "Yellow"
        $Ack = Read-Host "    (Type 'OK' to proceed)"
        if ($Ack -notmatch '^(1\.77245|OK)$') {
            Write-EntraLog "[-] User aborted AD modifications due to Retained Mailbox risk." "Yellow"
            Pause; return
        }
    }

    if ($TotalMatches -eq 0) {
        Write-EntraLog "[-] No AD matches found in the selected OU. Aborting." "Red"
        Pause; return
    }

    $AllMatches = $ActiveMatches + $DisabledMatches
    
    while ($true) {
        Write-EntraLog "[?] Ready to align $($TotalMatches) AD accounts." "Cyan"
        $Confirm = Read-Host "    (Type 'YES' to modify AD, 'REVIEW' or press Enter to view pending changes)"
        
        if ($Confirm -match '(?i)^REVIEW$' -or [string]::IsNullOrWhiteSpace($Confirm)) {
            Write-EntraLog "    [*] Launching GridView..." "Cyan"
            $AllMatches | 
            Select-Object @{N = "Action"; E = { "Align Properties" } },
            @{N = "Cloud_UPN"; E = { $_.CloudUser } }, 
            @{N = "AD_SamAccountName"; E = { $_.ADUser.SamAccountName } }, 
            @{N = "AD_Enabled"; E = { $_.ADUser.Enabled } },
            @{N = "AD_OldUPN"; E = { $_.ADUser.UserPrincipalName } } | 
            Out-ConsoleGridView -Title "REVIEW PENDING AD ALIGNMENTS ($TotalMatches Accounts)" -OutputMode None
        }
        elseif ($Confirm -ne 'YES') {
            Write-EntraLog "[-] User aborted AD modifications." "Yellow"
            Pause; return
        }
        else {
            break
        }
    }
    foreach ($Item in $AllMatches) {
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
            [string[]]$Proxies = @($Target.proxyAddresses | Where-Object { $_ -notlike "*$UPN*" })
            $Proxies += "SMTP:$UPN"
            
            Set-ADUser -Identity $Target.DistinguishedName -UserPrincipalName $UPN -EmailAddress $UPN -Replace @{ proxyAddresses = $Proxies } -ErrorAction Stop
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

# --- Framework Feature: Sync Analyzer ---
function Invoke-SyncAnalyzer {
    Write-EntraHeader "ENTRA CONNECT SYNC ANALYZER"
    Write-Host "This tool parses the CSV output from Microsoft's CSExportAnalyzer utility." -ForegroundColor DarkGray
    Write-Host "It will tally successful 'Update' soft-matches vs failed 'Add' duplicates.`n" -ForegroundColor DarkGray

    $CsvPath = Read-Host "Enter the absolute path to your CSExportAnalyzer CSV file"
    if (-not (Test-Path $CsvPath) -or ($CsvPath -notmatch '\.csv$')) {
        Write-EntraLog "[-] Invalid file path or not a .csv file." "Red"
        Pause; return
    }

    Write-EntraLog "[*] Parsing $CsvPath..." "Cyan"
    try {
        $Data = Import-Csv $CsvPath

        if (-not $Data[0].PSObject.Properties.Match('Omit').Count -or -not $Data[0].PSObject.Properties.Match('DN').Count) {
            Write-EntraLog "[-] The CSV does not appear to be generated by CSExportAnalyzer (Missing 'Omit' or 'DN' columns)." "Red"
            Pause; return
        }

        $Updates = $Data | Where-Object { $_.Omit -eq 'Update' }
        $Adds = $Data | Where-Object { $_.Omit -eq 'Add' }

        Write-Host "`n==== ANALYSIS RESULTS ====" -ForegroundColor Cyan
        Write-Host "Total Operations Parsed : $($Data.Count)"
        Write-Host "Successful Soft-Matches : $($Updates.Count) (Updates)" -ForegroundColor Green
        Write-Host "Failed Soft-Matches     : $($Adds.Count) (Adds)`n" -ForegroundColor Yellow

        if ($Adds.Count -gt 0) {
            Write-EntraLog "[!] Opening grid view for Failed Matches (Adds)." "Yellow"
            $Adds | Select-Object Omit, DN | Out-ConsoleGridView -Title "FAILED SOFT-MATCHES (Pending Cloud Duplicates)" -OutputMode None
        }
        else {
            Write-EntraLog "[+] Flawless execution! No 'Add' operations detected. All accounts soft-matched successfully!" "Green"
        }
    }
    catch {
        Write-EntraLog "[-] Failed to parse CSV: $($_.Exception.Message)" "Red"
    }
    Pause
}

# --- Main Console Entry Point ---
function Start-EntraSyncConsole {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host "[!] INCOMPATIBLE RUNTIME" -ForegroundColor Red
        Write-Host "EntraSyncEngine requires PowerShell 7+ for ConsoleGuiTools compatibility." -ForegroundColor Yellow
        Write-Host "You are currently running PowerShell version $($PSVersionTable.PSVersion.ToString())." -ForegroundColor Yellow
        Write-Host "Please install PowerShell 7 (pwsh) and relaunch." -ForegroundColor White
        Pause; return
    }

    Initialize-EntraFramework
    
    $MenuItems = @(
        [PSCustomObject]@{ Key = "0"; Label = "[GUIDE]  Read Deployment Workflow"; Action = { Invoke-DeploymentGuide } }
        [PSCustomObject]@{ Key = "1"; Label = "[CLOUD]  Run Graph Audit"; Action = { Invoke-CloudAudit } }
        [PSCustomObject]@{ Key = "2"; Label = "[LOCAL]  Align AD Attributes"; Action = { Invoke-ADAlignment } }
        [PSCustomObject]@{ Key = "3"; Label = "[SYNC]   Analyze Entra Connect Results"; Action = { Invoke-SyncAnalyzer } }
        [PSCustomObject]@{ Key = "4"; Label = "[VIEW]   Examine History"; Action = { if (Test-Path $EntraConfig.Manifest) { Import-Csv $EntraConfig.Manifest | Out-GridView -Title "History" } else { Write-EntraLog "No history found." "Yellow"; Pause } } }
        [PSCustomObject]@{ Key = "5"; Label = "[UNDO]   Rollback Engine"; Action = { Invoke-Rollback } }
        [PSCustomObject]@{ Key = "6"; Label = "[EXT]    Manage Extensions (SSO/Writeback)"; Action = { Invoke-ExtensionMenu } }
        [PSCustomObject]@{ Key = "Q"; Label = "[EXIT]"; Action = { return } }
    )
    
    $SelectedIndex = 0
    $KeepRunning = $true

    while ($KeepRunning) {
        Write-EntraHeader "MAIN CONSOLE"
        Write-Host "   Use Up/Down Arrows to navigate, Enter to select, or Number keys to jump.`n" -ForegroundColor DarkGray
        
        for ($i = 0; $i -lt $MenuItems.Count; $i++) {
            if ($i -eq $SelectedIndex) {
                Write-Host "  -> $($MenuItems[$i].Key).) $($MenuItems[$i].Label) " -ForegroundColor Black -BackgroundColor Cyan
            }
            else {
                Write-Host "     $($MenuItems[$i].Key).) $($MenuItems[$i].Label) " -ForegroundColor White
            }
        }
        
        $KeyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        if ($KeyInfo.VirtualKeyCode -eq 38) {
            # Up Arrow
            $SelectedIndex--
            if ($SelectedIndex -lt 0) { $SelectedIndex = $MenuItems.Count - 1 }
        }
        elseif ($KeyInfo.VirtualKeyCode -eq 40) {
            # Down Arrow
            $SelectedIndex++
            if ($SelectedIndex -ge $MenuItems.Count) { $SelectedIndex = 0 }
        }
        elseif ($KeyInfo.VirtualKeyCode -eq 13) {
            # Enter
            if ($MenuItems[$SelectedIndex].Key -eq "Q") {
                $KeepRunning = $false
            }
            else {
                & $MenuItems[$SelectedIndex].Action
                if ($SelectedIndex -lt ($MenuItems.Count - 2)) {
                    $SelectedIndex++ # Auto-advance to the next logical step
                }
            }
        }
        else {
            $Char = $KeyInfo.Character.ToString().ToUpper()
            for ($i = 0; $i -lt $MenuItems.Count; $i++) {
                if ($MenuItems[$i].Key -eq $Char) {
                    $SelectedIndex = $i
                    if ($MenuItems[$i].Key -eq "Q") {
                        $KeepRunning = $false
                    }
                    else {
                        & $MenuItems[$i].Action
                        if ($SelectedIndex -lt ($MenuItems.Count - 2)) {
                            $SelectedIndex++ # Auto-advance
                        }
                    }
                    break
                }
            }
        }
    }
}

Export-ModuleMember -Function Start-EntraSyncConsole