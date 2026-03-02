# EntraSyncEngine Deployment Workflow

This tool is designed to be used structurally across three distinct phases in order to surgically align your on-premise AD environment to Microsoft Entra ID prior to enabling Microsoft Entra Connect Sync.

---

## Phase 1: Pre-Sync (The "Soft-Match" Preparation)
**Run this BEFORE installing or enabling Microsoft Entra Connect / Cloud Sync.**

1. **Cloud Audit (Option 1):** Execute the Graph Audit first. This will authenticate via your tenant (ensuring the `organizations` scope) to pull an export of all the active, licensed cloud accounts you want to match.
2. **AD Attribute Alignment (Option 2):** Use the CSV generated from the Cloud Audit to surgically alter your on-premise `UserPrincipalName`, `mail`, and `proxyAddresses`.
    - *Why?* Microsoft Entra Connect performs a "Soft-Match" based on these explicit properties. If they align perfectly, your on-premise identity claims the Entra ID mailbox rather than provisioning a duplicate `*.onmicrosoft.com` account. 
    - *Safety:* This phase creates a full XML backup of AD prior to execution and logs every transaction in the manifest so you can safely use **Option 4: Rollback**.

## Phase 2: Install Microsoft Entra Connect
**Run the official Microsoft Entra Connect wizard.**

At this point, your identities are perfectly aligned. Run the installer from Microsoft. It will seamlessly "Soft-Match" your cloud users to your local AD users. The installer will also configure its prerequisites, such as creating the `MSOL_` execution account and setting up the `AZUREADSSOACC` computer object for Single Sign-On.

## Phase 3: Post-Sync Verification & Configuration
**Run this AFTER Entra Connect is installed to tidy up advanced capabilities.**

From the **Extensions Menu (Option 5)**, you can finish up the robust capabilities:
1. **Password Writeback:** Entra Connect just generated the `MSOL_` account in your domain. Run the `Feature_WritebackPermissions` extension so it can identify the account and dynamically provide you the `dsacls` code to apply explicit "Change Password" and "Reset Password" delegations across your domain root. Ensure this matches what was deployed in Entra Connect!
2. **Seamless SSO:** Check the Entra SSO integrity by executing the `Feature_SeamlessSSO` extension. This confirms the SPN `HOST/autologon.microsoftazuread-sso.com` was tied correctly to the `AZUREADSSOACC` machine.
3. **Connectivity Tests:** Easily ping the Microsoft Logon endpoints and local AD bounds via the connectivity extension if Azure AD Connect is reporting health issues.
