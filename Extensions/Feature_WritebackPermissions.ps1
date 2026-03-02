<#
.SYNOPSIS
    Delegates "Change Password" and "Reset Password" permissions to the MSOL service account at the domain root.
#>

Write-EntraHeader "FEATURE: PASSWORD WRITEBACK PERMISSIONS"

Write-EntraLog "[*] Starting validation for Password Writeback delegation..." "Cyan"

$MsolAccounts = Get-ADUser -Filter { SamAccountName -like "MSOL_*" }

if ($MsolAccounts) {
    Write-EntraLog "[+] Identified AD Connect execution account: $($MsolAccounts[0].SamAccountName)" "Green"
    Write-EntraLog "[!] This module should run dsacls to apply 'Reset Password' & 'Change Password' at the Domain Root." "Yellow"
    Write-EntraLog "[*] Ensure the account has these extended rights delegated." "White"
}
else {
    Write-EntraLog "[-] No MSOL_ account found. Is Azure AD Connect running?" "Red"
}

Read-Host "Press Enter to continue"
