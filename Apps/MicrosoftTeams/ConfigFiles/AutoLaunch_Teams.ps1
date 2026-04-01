[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$InstalledVersion
)


try{
    $version = Get-Appxpackage -Name MSteams
    foreach($versions in $version)
    {
        Write-Host "$versions"
        $version
        if($versions.version -eq $InstalledVersion)
        {
            $InstallLoc = $versions.InstallLocation
            $exe = "$InstallLoc\ms-teams.exe"
            Start-Process -FilePath $exe
            return 0
        }
    }
}
catch{
    Write-Host $_
    return 1
}