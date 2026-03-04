<#
.SYNOPSIS
    Configures and verifies the AZUREADSSOACC computer object and SPNs for Seamless Single Sign-On.
#>

Write-EntraHeader "FEATURE: SEAMLESS SSO"

Write-EntraLog "[*] Checking Seamless SSO configuration..." "Cyan"

$SsoAccount = Get-ADComputer -Identity "AZUREADSSOACC" -ErrorAction SilentlyContinue

if ($SsoAccount) {
    Write-EntraLog "[+] AZUREADSSOACC computer object exists." "Green"
    
    $Spns = $SsoAccount.ServicePrincipalNames
    if ($Spns -contains "HOST/autologon.microsoftazuread-sso.com") {
        Write-EntraLog "[+] Core expected SPN 'HOST/autologon.microsoftazuread-sso.com' found on AZUREADSSOACC." "Green"
    }
    else {
        Write-EntraLog "[-] Missing expected SPN on AZUREADSSOACC." "Yellow"
    }
}
else {
    Write-EntraLog "[-] AZUREADSSOACC computer object not found. Seamless SSO may not be enabled or configured correctly." "Yellow"
}

Read-Host "Press Enter to continue"
