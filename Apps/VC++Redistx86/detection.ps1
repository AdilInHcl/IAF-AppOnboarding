$AppName = "VC++Redistx86"
$Version = "###VERSION###"

# Registry paths for installed applications
$RegPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# Find installed VC++ x64 Redistributable 14.x
$InstalledApp = Get-ItemProperty $RegPaths |
    Where-Object {
        $_.DisplayName -like "Microsoft Visual C++ * Redistributable (x86)*" -and
        $_.DisplayVersion -like "14.*" -and
        $_.SystemComponent -ne 1
    }

if ($InstalledApp) {
    $InstalledAppVersion = $InstalledApp.DisplayVersion
        Write-Output [version]$InstalledAppVersion
        Write-Output [version]$Version
    if ([version]$InstalledAppVersion -ge [version]$Version) {
        Write-Output "$AppName is installed and version $InstalledAppVersion is compliant."
    }
    else {
        Write-Output "$AppName is installed with lower version $InstallAppVersion which is not compliant. Upgrading it to complaint $InstallAppVersion version."
        Exit 1
    }
}
else {
    Write-Output "$AppName is not installed."
    Exit 1
}