<#
.SYNOPSIS
    Delegates "Change Password" and "Reset Password" permissions to the MSOL service account at the domain root.
#>

Write-EntraHeader "FEATURE: PASSWORD WRITEBACK PERMISSIONS"

Write-EntraLog "[*] Starting validation for Password Writeback delegation..." "Cyan"

$MsolAccounts = Get-ADUser -Filter { SamAccountName -like "MSOL_*" }

if ($MsolAccounts) {
    $Msol = $MsolAccounts[0].SamAccountName
    $DomainObj = Get-ADDomain
    $DomainDistinguishedName = $DomainObj.DistinguishedName
    $DomainNetBIOS = $DomainObj.NetBIOSName

    Write-EntraLog "[+] Identified AD Connect execution account: $Msol" "Green"
    Write-EntraLog "[!] To enable Password Writeback, run the following dsacls command from an elevated prompt:" "Yellow"
    
    $Cmd = "dsacls `"$DomainDistinguishedName`" /I:S /G `"$($DomainNetBIOS)\$Msol:CA;Reset Password`" `"$($DomainNetBIOS)\$Msol:CA;Change Password`""
    Write-Host "`n$Cmd`n" -ForegroundColor DarkCyan
    
    Write-EntraLog "[*] Alternatively, refer to Guides\WritebackPermissions.md for the manual GUI walkthrough." "White"
}
else {
    Write-EntraLog "[-] No MSOL_ account found. Is Azure AD Connect running?" "Red"
}

Read-Host "Press Enter to continue"
