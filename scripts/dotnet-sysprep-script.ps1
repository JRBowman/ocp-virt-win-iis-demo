# Function to Install the ASP.NET Core Hosting Module for IIS.
function Add-IISASPCoreHostingModule {

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
}

# Function to Configure the CPU and Memory Limits on an IIS AppPool.
function Set-IISAppPoolLimits {
    param (
        [string]$AppPoolName,
        [int]$CPULimit,
        [int]$MemoryLimit
    )

    # Import the WebAdministration module if not already loaded
    Import-Module WebAdministration

    # Check if the Application Pool already exists
    if (Get-WebAppPoolState -Name $AppPoolName -ErrorAction SilentlyContinue) {
        Write-Host "Application Pool '$AppPoolName' Exists."

        # Set the CPU limits
        Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name "cpu.limit" -Value $CPULimit
        Write-Host "CPU Limit for '$AppPoolName' set to $CPULimit%."

        # Set the Memory limits
        Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name "recycling.periodicRestart.privateMemory" -Value $MemoryLimit
        Write-Host "Memory Limit for '$AppPoolName' set to $MemoryLimit."
    } else {
        Write-Host "Application Pool '$AppPoolName' does not exist, can't set Limits."
    }

    Write-Host "'$AppPoolName' Limits have been configured!"
}

function New-FirewallRule {
    param (
        [string]$Name,
        [int]$Port
    )

    # Check if a firewall rule with the specified name already exists
    $existingRule = Get-NetFirewallRule -DisplayName $Name -ErrorAction SilentlyContinue

    if ($null -ne $existingRule) {
        Write-Host "Firewall rule '$Name' already exists. Skipping creation."
    } else {
        # Create a new inbound firewall rule
        New-NetFirewallRule -DisplayName $Name `
                            -Direction Inbound `
                            -LocalPort $Port `
                            -Protocol TCP `
                            -Action Allow `
                            -Profile Any `
                            -Description "Inbound rule for $Name on port $Port"
        Write-Host "Firewall rule '$Name' created successfully for port $Port."
    }
}

function New-IISSiteWithAppPool {
    param (
        [string]$SiteName,
        [string]$AppPoolName,
        [string]$PhysicalPath,
        [int]$Port
    )

    # Import the WebAdministration module if not already loaded
    Import-Module WebAdministration

    # Check if the Application Pool already exists, if not create it
    if (Test-Path "IIS:\AppPools\$AppPoolName") {
        Write-Host "Application Pool '$AppPoolName' already exists. Skipping creation."
    } else {
        New-WebAppPool -Name $AppPoolName
        Write-Host "Application Pool '$AppPoolName' created successfully."
    }

    # Check if the site already exists
    if (Test-Path "IIS:\Sites\$SiteName") {
        Write-Host "Site '$SiteName' already exists. Skipping creation."
    } else {
        # Ensure the physical path exists
        if (-not (Test-Path $PhysicalPath)) {
            New-Item -Path $PhysicalPath -ItemType Directory -Force
            Write-Host "Physical path '$PhysicalPath' created."
        }

        # Create the new site
        New-Website -Name $SiteName -Port $Port -PhysicalPath $PhysicalPath -ApplicationPool $AppPoolName
        Write-Host "Site '$SiteName' created and bound to port $Port."
    }

    # Create the Site Binding:
    #New-IISBinding -SiteName $SiteName -Port $Port

    Write-Host "'$SiteName' has been created and is now serving on: http://*:$Port"
}

# Function to Download ZIP of Pre-Compiled .NET Binaries and Transfer to IIS Site Directory.
function New-DotNetIISApplication {
    param (
        [string]$Name,
        [string]$URL,
        [string]$TargetDirectory
    )

    # Create Temp Directory if it doesn't exist
    if (-Not (Test-Path "C:\Temp")) {
        New-Item -ItemType Directory -Path "C:\Temp"
    }

    $zipFilePath = "C:\Temp\$Name.zip";

    Invoke-WebRequest -Uri $URL -OutFile $zipFilePath

    # Unzip the contents:
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, "C:\Temp\$Name")

    # Copy the contents of the app to the IIS Directory:
    $destinationPath = "C:\Temp\$Name"
    Copy-Item -Path "$destinationPath\*" -Destination $TargetDirectory -Recurse -Force

    Write-Host "Application Binaries copied to '$TargetDirectory' directory."

    # Clean up
    Remove-Item -Path $destinationPath -Force
    Remove-Item -Path $zipFilePath -Force

    Write-Host "Application Binary artifacts cleaned up from 'C:\Temp'."
}

# Function Create a Binding for an IIS Site.
function New-IISBinding {
    param (
        [string]$SiteName,
        [int]$Port
    )

     # Check if the site binding already exists
    $bindingExists = Get-WebBinding -Name $SiteName -BindingInformation "*:$Port" -ErrorAction SilentlyContinue
    if (!$bindingExists) {
        # Add a new binding for the application
        New-WebBinding -Name $SiteName -Protocol "http" -Port $Port -IPAddress "*" -HostHeader ""
        Write-Host "HTTP Binding added for '$SiteName' on port $Port."
    } else {
        Write-Host "Binding on port $Port already exists for site '$SiteName'."
    }
}

# Function to Create and Configure an IIS WebSite, AppPool, and Add a .NET Application.
function Add-IISSiteToPool {
    param (
        [string]$SiteName,
        [string]$AppPoolName,
        [string]$AppUrl,
        [int]$Port,
        [int]$CPULimit = 25,
        [int]$MemoryLimitKB = 512000
    )

    # Create the Pool:
    $physicalPath = "C:\inetpub\$SiteName";

    # 1.) Create Site, App Pool, and Bindings:
    New-IISSiteWithAppPool -SiteName $SiteName -AppPoolName $AppPoolName -PhysicalPath $physicalPath -Port $Port

    # 2.) Set Limits:
    Set-IISAppPoolLimits -AppPoolName $AppPoolName -CPULimit $CPULimit -MemoryLimit $MemoryLimitKB

    # 3.) Obtain and Copy the .NET Application to the Site Directory:
    New-DotNetIISApplication -Name $SiteName -URL $AppUrl -TargetDirectory $physicalPath

    # 4.) Create a Windows Inbound Firewall Rule:
    New-FirewallRule -Name $SiteName -Port $Port

    Write-Host ""
    Write-Host "'$SiteName' Created."
}

# Main Script to Create and Configure IIS Sites:

## 1.) IIS Hosting Module:
Add-IISASPCoreHostingModule

## 2.) Add the .NET ASP Application to IIS:
$solacetkBackendUrl = "https://github.com/JRBowman/ocp-virt-win-iis-demo/raw/master/solacetk-core-app.zip"
#$solacetkIdentityUrl = "https://github.com/JRBowman/ocp-virt-win-iis-demo/raw/master/dotnet-identity-app.zip"

Add-IISSiteToPool -SiteName "SolaceTK-Core" -AppPoolName "SolaceTK-Core" -AppUrl $solacetkBackendUrl -Port 8080
#Add-IISSiteToPool -SiteName "SolaceTK-Identity" -AppPoolName "SolaceTK-Identity" -AppUrl $solacetkIdentityUrl -Port 8081