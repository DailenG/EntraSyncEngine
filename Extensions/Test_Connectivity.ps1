<#
.SYNOPSIS
    Verifies reachability of DCs and Entra endpoints before a sync.
#>

Write-EntraHeader "TEST CONNECTIVITY"

Write-EntraLog "[*] Testing Domain Controller reachability..." "Cyan"
$Dc = Get-ADDomainController -ErrorAction SilentlyContinue
if ($Dc) {
    Write-EntraLog "[+] Reached DC: $($Dc.HostName)" "Green"
}
else {
    Write-EntraLog "[-] Failed to reach any Domain Controller." "Red"
}

Write-EntraLog "[*] Testing Entra ID / Microsoft Graph reachability..." "Cyan"
try {
    Invoke-WebRequest -Uri "https://graph.microsoft.com/v1.0" -UseBasicParsing -ErrorAction Stop | Out-Null
    Write-EntraLog "[+] Successfully reached graph.microsoft.com" "Green"
}
catch {
    if ($_.Exception.Response) {
        Write-EntraLog "[+] Successfully reached graph.microsoft.com (HTTP Endpoint Responding)" "Green"
    }
    else {
        Write-EntraLog "[-] Failed to reach graph.microsoft.com" "Red"
    }
}

try {
    Invoke-WebRequest -Uri "https://login.microsoftonline.com" -UseBasicParsing -ErrorAction Stop | Out-Null
    Write-EntraLog "[+] Successfully reached login.microsoftonline.com" "Green"
}
catch {
    if ($_.Exception.Response) {
        Write-EntraLog "[+] Successfully reached login.microsoftonline.com" "Green"
    }
    else {
        Write-EntraLog "[-] Failed to reach login.microsoftonline.com" "Red"
    }
}

Read-Host "Press Enter to continue"
