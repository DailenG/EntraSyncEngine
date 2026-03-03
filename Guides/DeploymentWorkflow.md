# EntraSyncEngine Deployment Workflow

This tool is designed to be used structurally across three distinct phases in order to surgically align your on-premise AD environment to Microsoft Entra ID prior to enabling Microsoft Entra Connect Sync.

---

## Phase 1: Pre-Sync (The "Soft-Match" Preparation)
**Run this BEFORE installing or enabling Microsoft Entra Connect / Cloud Sync.**

1. **Cloud Audit (Option 1):** Execute the Graph Audit first. This will authenticate via your tenant (ensuring the `organizations` scope) to pull an export of all the active, licensed cloud accounts you want to match.
2. **AD Attribute Alignment (Option 2):** Use the CSV generated from the Cloud Audit to surgically alter your on-premise `UserPrincipalName`, `mail`, and `proxyAddresses`.
    - *Safety:* This phase creates a full XML backup of AD prior to execution and logs every transaction in the manifest so you can safely use **Option 4: Rollback**.

### Edge Case: Retained Mailboxes (Disabled AD Accounts)
> **WARNING:** If you have active cloud mailboxes belonging to disabled AD accounts (e.g., terminated employees whose mailboxes are being retained), **Microsoft Entra Connect Sync will disable their cloud accounts** when it bridges the `accountEnabled` states, effectively breaking mailbox access.
>
> The Engine's Pre-Flight check actively hunts for these matches. If it finds active cloud accounts mapping to disabled AD accounts, it will halt and explicitly warn you. It requires you to either physically type `OK` or solve a math equation (`√π`) to proceed, actively breaking muscle-memory confirmation. If this happens, you MUST either exclude those specific disabled AD accounts from your sync scope within the Entra Connect wizard, or leave them unmatched!

### The Pre-Sync Review Grid
> Before committing any surgical changes to Active Directory, the engine will prompt you with an interactive `Out-ConsoleGridView` table. Typing `REVIEW` at the confirmation prompt allows you to visually audit every pending AD attribute overwrite (UPN, SAM, Enable State) to ensure the matching logic performed safely before committing database writes.

## Phase 2: Install Microsoft Entra Connect
**Run the official Microsoft Entra Connect wizard.**

At this point, your identities are perfectly aligned. Run the installer from Microsoft. It will seamlessly "Soft-Match" your cloud users to your local AD users.

> **CRITICAL ENTRA CONNECT MATCH REQUIREMENT:**
> During the Entra Connect installation wizard, you MUST configure the sync engine to match based on **UserPrincipalName** or **Mail** attribute. Do *not* rely on `ms-DS-ConsistencyGuid` for the initial alignment sync, or the soft-match logic may fail to bridge the disparate environments.

The installer will also configure its prerequisites, such as creating the `MSOL_` execution account and setting up the `AZUREADSSOACC` computer object for Single Sign-On.

## Phase 3: Post-Sync Verification & Configuration
**Run this AFTER Entra Connect is installed to tidy up advanced capabilities.**

From the **Extensions Menu (Option 5)**, you can finish up the robust capabilities:
1. **Password Writeback:** Entra Connect just generated the `MSOL_` account in your domain. Run the `Feature_WritebackPermissions` extension so it can identify the account and dynamically provide you the `dsacls` code to apply explicit "Change Password" and "Reset Password" delegations across your domain root. Ensure this matches what was deployed in Entra Connect!
2. **Seamless SSO:** Check the Entra SSO integrity by executing the `Feature_SeamlessSSO` extension. This confirms the SPN `HOST/autologon.microsoftazuread-sso.com` was tied correctly to the `AZUREADSSOACC` machine.
3. **Connectivity Tests:** Easily ping the Microsoft Logon endpoints and local AD bounds via the connectivity extension if Azure AD Connect is reporting health issues.
