# Password Writeback Configurations

If you prefer to configure Password Writeback manually via the GUI instead of using the generated `dsacls` command, please follow this guide carefully to avoid accidental Active Directory lockouts. 

## Context: 
Azure AD Connect uses a predefined local Active Directory Account (formatted as `MSOL_xxxxxxxxxxxx`) to manipulate user attributes on-premise. For Password Writeback (the capability for cloud-assigned passwords to replicate down to the on-premise environment), this `MSOL_` account needs explicit uninherited security delegations on the entire AD Domain.

## Walkthrough: Enabling Delegations
1. Look up your MSOL account name. You can run `Feature_WritebackPermissions.ps1` from the EntraSyncEngine's extension menu to discover it.
2. Open **Active Directory Users and Computers** (`dsa.msc`) on a Domain Controller. Make sure you are elevated.
3. Click on the **View** menu at the top and ensure **Advanced Features** is enabled (checked on).
4. Right-click the root of your domain (e.g. `constoso.com`) and choose **Properties**.
5. Navigate to the **Security** tab. You may receive a pop-up regarding large objects; proceed past it.
6. Click **Advanced** towards the bottom.
7. Click **Add** to create a new permission entry.
8. Click **Select a principal**, type in your MSOL account (e.g. `MSOL_38fb1b29a...`), and click **Check Names**. Once resolved, click **OK**.
9. In the **Applies to** dropdown, ensure this is set to: **Descendant User objects** (This restricts the rights solely to users, preventing accidental changes to admin objects).
10. Below the Properties pane, scroll down to the **Permissions** block. Mark the boxes explicitly for:
    - `Reset Password`
    - `Change Password`
11. Click **OK** on the Permission Entry, **OK** on the Advanced Security Settings, and **OK** on the Domain Properties.

Your MSOL account is now properly configured. Azure AD Connect will handle password replications gracefully.
