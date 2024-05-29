## 1.) IIS Hosting Module:

# Variables
$downloadUrl = "https://download.visualstudio.microsoft.com/download/pr/70f96ebd-54ce-4bb2-a90f-2fbfc8fd90c0/aa542f2f158cc6c9e63b4287e4618f0a/dotnet-hosting-8.0.5-win.exe"
$installerPath = "C:\Temp\dotnet-hosting-8.0.5-win.exe"

# Create Temp Directory if it doesn't exist
if (-Not (Test-Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp"
}

# Download the Installer
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

# Install the MSI/EXE
Start-Process -FilePath $installerPath -ArgumentList "/quiet" -Wait

# Verify Installation
$installed = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*Microsoft ASP.NET Core Module*" }

if ($installed) {
    Write-Host ".NET 8 IIS Hosting Module installed successfully."
} else {
    Write-Host "Installation failed."
}

# Clean up
Remove-Item -Path $installerPath -Force

## 2.) Add the .NET ASP Application to IIS:

# Variables
$dotnetUrl = "https://github.com/JRBowman/ocp-virt-win-iis-demo/raw/master/dotnet-iis-app.zip"
$zipFilePath = "C:\Temp\dotnet-iis-app.zip"
$destinationPath = "C:\Temp\dotnet-iis-app"
$iisDefaultSitePath = "C:\inetpub\wwwroot"

# Create Temp Directory if it doesn't exist
if (-Not (Test-Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp"
}

# Download the Installer
Invoke-WebRequest -Uri $dotnetUrl -OutFile $zipFilePath

# Unzip the contents:
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $destinationPath)

# Copy the contents of the app to the IIS Directory:
Copy-Item -Path "$destinationPath\*" -Destination $iisDefaultSitePath -Recurse -Force

Write-Host "Contents copied to IIS Default Site directory successfully."

# Clean up
Remove-Item -Path $destinationPath -Force
Remove-Item -Path $zipFilePath -Force