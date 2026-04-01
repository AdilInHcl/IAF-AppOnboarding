#Define Provisioned Appx Package name and minimum version
$AppxName = "KeeperSecurityInc.KeeperPasswordManager"
$AppName = "Keeper Desktop Manager"
$Version = "###VERSION###"
#Get the app (if installed) and get the version number
$InstalledApp = Get-AppxProvisionedPackage -Online | where DisplayName -eq $AppxName -ErrorAction SilentlyContinue

$InstalledAppVersion = $InstalledApp.Version
#If the app is installed, check the app version against the minimum required version
if ($InstalledApp) {
        Write-Output [version]$InstalledAppVersion
        Write-Output [version]$Version
    if ([version]$InstalledAppVersion -ge [version]$Version) {
        Write-Output "$AppName is installed and version $InstalledAppVersion is compliant."
    }
    else {
        Write-Output "$AppName is installed with lower version $InstallAppVersion which is not compliant. Upgrading it to complaint $Version version."
        Exit 1
    }
}
else {
    Write-Output "$AppName is not installed."
    Exit 1
}
