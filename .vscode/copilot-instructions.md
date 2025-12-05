# PowerShell Coding Rules for GitHub Copilot

## ALWAYS USE APPROVED POWERSHELL VERBS

When generating PowerShell functions, cmdlets, or modules:

- Only use verbs from the official PowerShell Approved Verbs list.
- NEVER use unapproved verbs such as run, execute, build, process, create, load, save, scan, upload, download, login, logout, print, render.
- Follow the format Verb-Noun with singular nouns.

### Examples:

✔ Correct:

- Get-User
- Set-Config
- New-Backup
- Start-Service
- Invoke-Migration

❌ Incorrect:

- Run-Backup
- Execute-Service
- Build-Hash
- Save-ConfigFile
- Create-UserFile
