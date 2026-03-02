# EntraSyncEngine Agent Documentation

## Project Context
The EntraSyncEngine is a modular, enterprise-grade PowerShell framework designed to facilitate seamless, safe on-premise Active Directory to Microsoft Entra ID migrations. It is built for Senior IT Systems Engineers operating at an MSP scale.

## Core Features
- **Cloud Audit**: Minimalist Microsoft Graph integration to discover active, licensed users.
- **AD Alignment**: Surgical manipulation of on-premise properties (UPN, Mail, ProxyAddresses) to guarantee Entra ID "Soft-Match".
- **Safety First**: XML state backups and CSV transaction manifests for point-in-time programmatic rollbacks.
- **Extensibility**: Plugin-based architecture dynamically executing scripts from an `Extensions/` directory.

## Technical Requirements
- Language: PowerShell 5.1+
- Modules Dependency: `Microsoft.Graph.Authentication`, `Microsoft.Graph.Users`, `ActiveDirectory`
- Strict error handling and enterprise logging logic must be maintained.
- Graph interactions must target "Work or School" accounts specifically (`-TenantId "organizations"`).

## Long-term Goals
- Ensure zero-impact alignment by retaining granular validation parameters.
- Provide a robust mechanism for reporting unaligned or disjointed identities.
- Grow the plugin ecosystem to support other Microsoft 365 migration tasks (e.g., Azure AD Connect health checks, SSO).
