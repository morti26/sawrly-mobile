# fotgraf_mobile

A new Flutter project.

## Deploy web with SSH

Build and upload the Flutter web app to a server over SSH:

```powershell
.\scripts\deploy-web.ps1 -Server example.com -User serveruser -RemotePath /var/www/sawrly
```

Optional flags:

```powershell
.\scripts\deploy-web.ps1 -Server example.com -User serveruser -RemotePath /var/www/sawrly -Port 2222 -IdentityFile C:\Users\mon24\.ssh\id_ed25519
.\scripts\deploy-web.ps1 -Server example.com -User serveruser -RemotePath /var/www/sawrly -SkipBuild
.\scripts\deploy-web.ps1 -Server example.com -User serveruser -RemotePath /var/www/sawrly -NoRemoteBackup
```

For GitHub backup, commit only the files you want to save and push:

```powershell
git status
git add README.md scripts/deploy-web.ps1
git commit -m "Add SSH web deploy script"
git push origin main
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
