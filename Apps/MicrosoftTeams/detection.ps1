#Define Provisioned Appx Package name and minimum version
$AppxName = "MSTeams"
$Version = "###VERSION###"
#Get the app (if installed) and get the version number
$InstalledApp = Get-AppxProvisionedPackage -Online | where DisplayName -eq $AppxName -ErrorAction SilentlyContinue
$InstalledAppVersion = $InstalledApp.Version
#If the app is installed, check the app version against the minimum required version
if ($InstalledApp) {
    if ([System.Version]"$InstalledAppVersion" -ge [System.Version]"$Version") {
            $InstallStatus = "Installed and version $InstalledAppVersion is compliant"
        } else {
        $InstallStatus = "Not up to date, so not compliant. Supported Version is $Version"
        }
    } else {
        $InstallStatus = "Not Installed"
}
if ($InstallStatus -eq "Installed and version $InstalledAppVersion is compliant") {
    write-output "$AppxName is $InstallStatus"
    }
if ($InstallStatus -eq "Not up to date, so not compliant. Supported Version is $Version") {
    write-output "$AppxName is $InstallStatus"
    Exit 1    
}
if ($InstallStatus -eq "Not Installed") {
    write-output "$AppxName is $InstallStatus"
    Exit 1
}
