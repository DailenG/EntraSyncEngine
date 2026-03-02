<div align="center">
  <img src="https://wdc.help/icons/wam.png" width="128" height="128" alt="WideData Logo">
  <h1>Entra Sync Engine</h1>
  <p><b>A professional identity alignment and management module for Hybrid AD environments.</b></p>
  <a href="https://deepwiki.com/DailenG/EntraSyncEngine"><strong>📚 Read the Interactive DeepWiki Documentation</strong></a>
</div>
<br/>

## Overview
The **EntraSyncEngine** is an enterprise-grade PowerShell framework developed specifically for MSPs and Senior Systems Engineers to facilitate safe, seamless migrations from on-premise Active Directory to Microsoft Entra ID.

Instead of performing blind manual exports or running risky mass-updates, the EntraSyncEngine provides a guided, interactive workflow to intelligently audit cloud identities, back up local directory structures, and securely align exact `UserPrincipalName`, `mail`, and `proxyAddress` attributes for perfect Entra Connect "Soft-Matching."

### 📖 Extensive Documentation
We strongly encourage all users, MSPs, and engineers to consult the official documentation before executing identity alignment in a production environment. 

The **[DeepWiki page for EntraSyncEngine](https://deepwiki.com/DailenG/EntraSyncEngine)** contains comprehensive, interactive guides detailing:
- The standard 3-Phase Deployment Workflow.
- Pre-Flight safety checks and "Retained Mailbox" edge-case handling.
- Extensibility via SSO and Password Writeback plugins.

## Quick Start
```powershell
# Install the module from the PowerShell Gallery
Install-Module -Name EntraSyncEngine -Scope CurrentUser

# Launch the interactive console (Requires PowerShell 7+)
Start-EntraSyncConsole
```

## Features
- **Cloud Audit**: Minimalist Microsoft Graph integration to discover active, licensed users.
- **Interactive AD Alignment**: Surgical, guided manipulation of on-premise properties. Uses `ConsoleGuiTools` for interactive OU scope selection.
- **Safety First**: Engine automatically performs XML state backups prior to modification and maintains CSV transaction manifests for point-in-time programmatic rollbacks.
- **Strict Edge-Case Protection**: Proactively hunts for disjointed identities (e.g., Active Entra mailboxes tied to Disabled AD accounts) and explicitly halts execution to prevent accidental cloud-account termination.

## Requirements
- **PowerShell 7 (`pwsh`)** or higher is strictly required for `ConsoleGuiTools` compatibility.
- Active Directory PowerShell Module (`RSAT-AD-PowerShell`).
- Microsoft Graph PowerShell SDK (Automatically installed by the framework if missing).

## Copyright
(c) 2026 WideData Corporation, Inc. All rights reserved.
