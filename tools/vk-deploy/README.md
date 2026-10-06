# Deploying Clown Smash to VK Mini Apps

Run PowerShell from the project root:

```powershell
.\tools\vk-deploy\Deploy-VK.ps1 -Target Dev
```

Choose `-Target Prod` to update production, or `-Target Both` to update both VK environments. The script defaults to development, validates that the build directory contains exactly the nine expected Web runtime files, prints their SHA-256 hashes, and requires typing a target-specific confirmation before uploading. Confirmation is case-insensitive.

The first deployment installs the pinned npm dependencies with `npm ci`. The official VK CLI handles VK authorization; do not put an access token in the script. The original `vk-hosting-config.json` is restored after the CLI exits.

The default build directory is `builds/vk`. To validate it without installing dependencies or uploading:

```powershell
.\tools\vk-deploy\Deploy-VK.ps1 -ValidateOnly
```
