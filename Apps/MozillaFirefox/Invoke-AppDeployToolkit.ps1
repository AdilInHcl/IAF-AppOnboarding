<#

.SYNOPSIS
PSAppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION
- The script is provided as a template to perform an install, uninstall, or repair of an application(s).
- The script either performs an "Install", "Uninstall", or "Repair" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script imports the PSAppDeployToolkit module which contains the logic and functions required to install or uninstall an application.

.PARAMETER DeploymentType
The type of deployment to perform.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive (shows dialogs), Silent (no dialogs), NonInteractive (dialogs without prompts) mode, or Auto (shows dialogs if a user is logged on, device is not in the OOBE, and there's no running apps to close).

Silent mode is automatically set if it is detected that the process is not user interactive, no users are logged on, the device is in Autopilot mode, or there's specified processes to close that are currently running.

.PARAMETER SuppressRebootPassThru
Suppresses the 3010 return code (requires restart) from being passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType Install -DeployMode Silent

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Invoke-AppDeployToolkit.ps1, and Invoke-AppDeployToolkit.exe
- 69000 - 69999: Recommended for user customized exit codes in Invoke-AppDeployToolkit.ps1
- 70000 - 79999: Recommended for user customized exit codes in PSAppDeployToolkit.Extensions module.

.LINK
https://psappdeploytoolkit.com

#>

[CmdletBinding()]
param
(
    # Default is 'Install'.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType,

    # Default is 'Auto'. Don't hard-code this unless required.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'Interactive', 'NonInteractive', 'Silent')]
    [System.String]$DeployMode,

    [Parameter(Mandatory = $false)]
    [ValidateSet('RAPPS')]
    [System.String]$Platform,

    [Parameter(Mandatory = $false)]
    [Switch]$NoDefer,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$SuppressRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


##================================================
## MARK: Variables
##================================================

# Zero-Config MSI support is provided when "AppName" is null or empty.
# By setting the "AppName" property, Zero-Config MSI will be disabled.
$adtSession = @{
    # App variables.
    AppVendor = '###APPPUBLISHER###'
    AppName = '###INTUNEAPPNAME###'
    AppVersion = '###VERSION###'
    AppArch = 'x86'
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppProcessesToClose = @('firefox')  # Example: @('excel', @{ Name = 'winword'; Description = 'Microsoft Word' })
    AppScriptVersion = '1.0.0'
    AppScriptDate = '###DATETIME###'
    AppScriptAuthor = 'IntuneAppFactory'
    RequireAdmin = $true
    APPID_Short = ""
	InstallerName = '###SETUPFILENAME###'
    AppID = '###APPID###'
    FamilyID = '###FAMILYID###'
    Platform = 'AMC and AVC'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ""
    InstallTitle = " "

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters = $PSBoundParameters
    DeployAppScriptVersion = '4.1.5'
    DeployAppScriptDate = '2026-02-11'
}

function Install-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close processes if specified, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt.
        if($Nodefer){
      $Defertime = 900
      $DeferCount = 0  
     
    }else{
        $Defertime = 900
        $DeferCount = 1
    }
 
    $saiwParams = @{
        AllowDefer = $true
        DeferTimes = $DeferCount
        CheckDiskSpace = $true
        PersistPrompt = $true
        ForceCountdown = $Defertime
    }
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        $saiwParams.Add('CloseProcesses', $adtSession.AppProcessesToClose)
 
        Show-ADTInstallationWelcome @saiwParams
    }

    ## <Perform Pre-Installation tasks here>


    ################################ Uninstall Firefox Apps version less that 140.0.0 & greater than or equal to 141.0.0 until 2026Q3 #############################
    
    
    $displayver = Get-ADTApplication -Name "*Mozilla Firefox*"
    $DisplayVer = $displayver.DisplayVersion
    If (($null -ne $displayver)){ 
    If (([version]$DisplayVer -lt [version]"140.0.0") -or ([version]$DisplayVer -lt [version]$($adtSession.AppVersion))){
        Uninstall-ADTApplication -Name "*Mozilla Firefox*" -ApplicationType 'MSI'
        Uninstall-ADTApplication -Name "*Mozilla Firefox*" -ApplicationType 'EXE' -ArgumentList "/S"
        Start-Sleep -Seconds 10
 
        function Get-ProcessRunning {
            param (
            [string]$ProcessName
            )
            $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            return $process
            }
        $processName = "Firefox" 
        Write-ADTLogEntry "Waiting for the process '$processName' to stop..."
        while (Get-ProcessRunning -ProcessName $processName) {
            Start-Sleep -Seconds 5 
        }
        Write-ADTLogEntry "Process '$processName' has stopped. Proceeding with Installation..."
        }
        }
        
                    
                    
                    

    ################################################################# Uninstallation of User installed Apps #######################################################################
    $LogU = Get-ADTLoggedOnUser
    $currentUserSID = $LogU.SID #Logged in user SID
    $registryPaths = @(
        "Registry::HKEY_USERS\$currentUserSID\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "Registry::HKEY_USERS\$currentUserSID\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    $uninstallString = $null
    $diplayver = $null
    foreach ($registryPath in $registryPaths) {
        $subkeys = Get-ChildItem -Path $registryPath -ErrorAction SilentlyContinue
        foreach ($subkey in $subkeys) {
            #$fullkey = $registryPath + "\" + $subkey
            $displayName = Get-ItemProperty -Path $subkey.PSPath -Name "DisplayName" -ErrorAction SilentlyContinue
        
            if ($displayName -like "*Mozilla Firefox*") {
                $uninstallString = Get-ItemProperty -Path $subkey.PSPath -Name "UninstallString" -ErrorAction SilentlyContinue
                $diplayver = Get-ItemProperty -Path $subkey.PSPath -Name "DisplayVersion" -ErrorAction SilentlyContinue
                $DisplayVer = $diplayver.DisplayVersion
                break
            }
        }
        
        if ($uninstallString) {
                break
            }
        }
    
    if ($uninstallString) {
        $uninstallCommand = $uninstallString.UninstallString + " /S"
        if (($uninstallString -like "*.exe*") -and ($uninstallString -notlike "*Msiexec.exe*")) {
        Try{
        Start-ADTProcess -FilePath "cmd.exe" -ArgumentList "/c `"$uninstallCommand`"" -CreateNoWindow
        while (Get-ProcessRunning -ProcessName $processName) { Start-Sleep -Seconds 5 }
        Remove-ADTFile -Path "HKEY_USERS\$currentUserSID\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Mozilla Firefox*"
        Remove-ADTFile -Path "HKEY_USERS\$currentUserSID\Software\\Microsoft\Windows\CurrentVersion\Uninstall\Mozilla Firefox*"
        Write-ADTLogEntry -Message "Uninstalled User installed Firefox(EXE) - $DisplayVer"
        Write-ADTLogEntry -Message "Uninstall Command used - $uninstallCommand"
        }Catch{
        Write-ADTLogEntry -Message "Uninstallation of user installed Firefox failed: $_ "
        }
    }else { Write-ADTLogEntry -Message "No Standard User installed Mozilla Firefox app found." }
    } else {
        Write-ADTLogEntry -Message "No Standard User installed Mozilla Firefox app found."
    }


    ######################################################################### Uninstallation Ends ###################################################################################

    #Cleanup

    $LogU = Get-ADTLoggedOnUser
    $LUname = $LogU.Username #Logged in username

    Remove-ADTFile -Path "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Mozilla Firefox*" -Recurse
    Remove-ADTFile -Path "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Mozilla Firefox*" -Recurse

    Remove-ADTFolder -Path "$envProgramData\Microsoft\Windows\Start Menu\Programs\Mozilla Firefox" 
    Remove-ADTFile -Path "$envSystemdrive\Users\Public\Desktop\Firefox.lnk"
    Remove-ADTFile -Path "$envSystemdrive\Users\$LUname\Desktop\Firefox.lnk"
    Remove-ADTFile -Path "$envSystemdrive\Users\$LUname\Desktop\Firefox Private Browsing.lnk"
    Remove-ADTFile -Path "$envSystemdrive\Users\$LUname\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Firefox Private Browsing.lnk"


    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name 'MOZ_CRASHREPORTER_DISABLE'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1016_Mozilla_Firefox_128.6_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\716_Mozilla_Firefox_128.0_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\302_Mozilla_Firefox_115.3.1_PKG_R2'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1016_Mozilla_Firefox_128.6_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1356_Mozilla_Firefox_128.9.0_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1356_Mozilla_Firefox_128.9.0_PKG_R2'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1762_Mozilla_Firefox_140.0_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1762_Mozilla_Firefox_140.0_PKG_R2'
    #Get-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\" | Where-Object { $_.PSChildName -like "1762_*" } | ForEach-Object { Remove-ADTRegistryKey -Key $_.PSPath }
 



    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI installations.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transforms', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
        if ($adtSession.DefaultMspFiles)
        {
            $adtSession.DefaultMspFiles | Start-ADTMsiProcess -Action Patch
        }
    }

    ## <Perform Installation tasks here>


    $displayver = Get-ADTApplication -Name "*Mozilla Firefox*"
    $displayver
    If (($null -eq $displayver))
    { 
            Start-ADTProcess -FilePath "$($adtSession.DirFiles)\$($adtSession.InstallerName)" -ArgumentList "/INI=`"$($adtSession.DirFiles)\setup.ini`"" -CreateNoWindow
            Start-Sleep -Seconds 5

        

        ##================================================
        ## MARK: Post-Install
        ##================================================
        $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

        ## <Perform Post-Installation tasks here>

        ##All user's configuration will be handled only with this if condition
        If($Platform -eq "RAPPS"){
            <#Write-ADTLogEntry -message "Platform - $Platform User configuration is being applied"
            
            #####RAPPS User config####

    
            #####All the ps1 file should be copied ########
            If(Test-Path "$envProgramdata\RAPPS_userconfig\$($adtSession.APPID_Short)\"){}
            else{
                New-ADTFolder -LiteralPath "$envProgramdata\RAPPS_userconfig\$($adtSession.APPID_Short)\"
            }

            Copy-ADTFile -Path "$($adtSession.DirFiles)\RAPPS\*" -Destination "$envProgramdata\RAPPS_userconfig\$($adtSession.APPID_Short)\"#>
        }
        else{
        <# Write-ADTLogEntry -Message "Applying user configuration for AMC/AVCC."
            
            ##### User config ###########
            
            ##### For all user related configuration in AMC & AVCC, config should be handled for Default profile also (If it's a Coreapp or It's for Device base Installation)
            #>
            
            
        }

        Copy-ADTFile -Path "$($adtSession.DirFiles)\override.ini" -Destination "$envProgramFiles\Mozilla Firefox\browser"
        Copy-ADTFile -Path "$($adtSession.DirFiles)\mozilla.cfg" -Destination "$envProgramFiles\Mozilla Firefox\"
        Copy-ADTFile -Path "$($adtSession.DirFiles)\local-settings.js" -Destination "$envProgramFiles\Mozilla Firefox\defaults\pref"
        Copy-ADTFile -Path "$($adtSession.DirFiles)\policies.json" -Destination "$envProgramFiles\Mozilla Firefox\distribution"
        Copy-ADTFile -Path "$($adtSession.DirFiles)\autoupdate.js" -Destination "$envProgramFiles\Mozilla Firefox\defaults\pref"

        #Desktop Shortcut removal
        $LogU = Get-ADTLoggedOnUser
        $LUname = $LogU.Username
        Remove-ADTFile -Path "$envSystemdrive\Users\Public\Desktop\Firefox.lnk"
        Remove-ADTFile -Path "$envSystemdrive\Users\$LUname\Desktop\Firefox.lnk"

        #Moving shortcuts to proper folder structure
        New-ADTFolder -Path "$envProgramData\Microsoft\Windows\Start Menu\Programs\Mozilla Firefox"
        Copy-ADTFile -Path "$envProgramData\Microsoft\Windows\Start Menu\Programs\Firefox*.lnk" -Destination "$envProgramData\Microsoft\Windows\Start Menu\Programs\Mozilla Firefox\"
        Remove-ADTFile -Path "$envProgramData\Microsoft\Windows\Start Menu\Programs\Firefox Private Browsing.lnk"
        Remove-ADTFile -Path "$envProgramData\Microsoft\Windows\Start Menu\Programs\Firefox.lnk"


        $ARPs = Get-ADTApplication -Name "Mozilla Firefox*"
        ForEach ($ARP in $ARPs){If ($($ARP.PSPath)) {
            Set-ADTRegistryKey -Key "$($ARP.PSPath)" -Name "NoModify" -Value "1" -Type DWord  
            Set-ADTRegistryKey -Key "$($ARP.PSPath)" -Name "NoRemove" -Value "1" -Type DWord
            Set-ADTRegistryKey -Key "$($ARP.PSPath)" -Name "NoRepair" -Value "0" -Type DWord
        }
        }


        # Permissions to folder for users

        
        $usersSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-11")
        $usersAccount = $usersSID.Translate([System.Security.Principal.NTAccount]).Value
        $Folder1 = Test-Path -Path "$envProgramFiles\Mozilla Firefox"
        if ($Folder1) {
                $sharepath = "$envProgramFiles\Mozilla Firefox"
                $Acl = Get-Acl $sharepath
                $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($usersAccount,"ReadandExecute","ContainerInherit,ObjectInherit","None","Allow")
                $Acl.AddAccessRule($AccessRule)
                Set-Acl $sharepath $Acl
            
                Write-ADTLogEntry "Permissions successfully updated to 'Users' for $sharepath folder "
            }
            
        $Folder2 = Test-Path -Path "$envProgramFilesx86\Mozilla Maintenance Service"
        if ($Folder2) {
                $sharepath = "$envProgramFilesx86\Mozilla Maintenance Service"
                $Acl = Get-Acl $sharepath
                $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($usersAccount,"ReadandExecute","ContainerInherit,ObjectInherit","None","Allow")
                $Acl.AddAccessRule($AccessRule)
                Set-Acl $sharepath $Acl
            
                Write-ADTLogEntry "Permissions successfully updated to 'Users' for $sharepath folder "
            }
            
        Set-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "MOZ_CRASHREPORTER_DISABLE" -Type "String" -Value "1" 
        Set-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Mozilla\MaintenanceService' -Name 'Enabled' -Type 'DWORD' -Value '1'
            
        #deleting the updater empty folders
        #if ((Get-ChildItem -Path "$envProgramFilesX86\Mozilla\TEST" -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) { Remove-ADTFolder -Path "$envProgramFilesX86\TEST" }
    $ARPs = Get-ADTApplication -Name 'Mozilla Firefox ESR*'
    if (Compare-Version $($adtSession.AppVersion) $ARPs.DisplayVersion "eq") {
        Branding-Key -Action "Create"
        If($Platform -eq "RAPPS"){ Set-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\$($adtSession.AppVendor)_$($adtSession.AppName)_PKG" -Name "Platform" -Value "AMC & AVC & RAPPS" -Type String }
    }{Write-ADTLogEntry -Message "Firefox app found, Skipping Branding deletion"}
    }
    else{Write-ADTLogEntry "Same or Higher version of Firefox Already installed"}

    
    
}

function Uninstall-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## If there are processes to close, show Welcome Message with a 10 minutes countdown before automatically closing.
    

    ## <Perform Pre-Uninstallation tasks here>

    Show-ADTInstallationWelcome -CloseProcesses @{Name ="firefox"} -Silent

    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI uninstallations.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transforms', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Uninstallation tasks here>


    $displayver = Get-ADTApplication -Name "*Mozilla Firefox*"
    If($null -ne $displayver){
    $DisplayVer = $displayver.DisplayVersion
    If (([version]$DisplayVer -lt [version]"140.0.0") -or ([version]$DisplayVer -le [version]$($adtSession.AppVersion))){
        Uninstall-ADTApplication -Name "*Mozilla Firefox*" -ApplicationType 'MSI'
        Uninstall-ADTApplication -Name "*Mozilla Firefox*" -ApplicationType 'EXE' -ArgumentList "/S"
        Start-Sleep -Seconds 10
 
        function Get-ProcessRunning {
            param (
            [string]$ProcessName
            )
            $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            return $process
            }
        $processName = "Firefox" 
        Write-ADTLogEntry "Waiting for the process '$processName' to stop..."
        while (Get-ProcessRunning -ProcessName $processName) {
            Start-Sleep -Seconds 5 
        }
        Write-ADTLogEntry "Process '$processName' has stopped. Proceeding with Installation..."
        }
        }



    #Uninstallation of User installed Apps 
    $LogU = Get-ADTLoggedOnUser
    $currentUserSID = $LogU.SID #Logged in user SID
    $registryPaths = @(
        "Registry::HKEY_USERS\$currentUserSID\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "Registry::HKEY_USERS\$currentUserSID\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    $uninstallString = $null
    $diplayver = $null
    foreach ($registryPath in $registryPaths) {
        $subkeys = Get-ChildItem -Path $registryPath -ErrorAction SilentlyContinue
        foreach ($subkey in $subkeys) {
            #$fullkey = $registryPath + "\" + $subkey
            $displayName = Get-ItemProperty -Path $subkey.PSPath -Name "DisplayName" -ErrorAction SilentlyContinue
        
            if ($displayName -like "*Mozilla Firefox*") {
                $uninstallString = Get-ItemProperty -Path $subkey.PSPath -Name "UninstallString" -ErrorAction SilentlyContinue
                $diplayver = Get-ItemProperty -Path $subkey.PSPath -Name "DisplayVersion" -ErrorAction SilentlyContinue
                $DisplayVer = $diplayver.DisplayVersion
                break
            }
        }
        
        if ($uninstallString) {
                break
            }
        }
    
    if ($uninstallString) {
        $uninstallCommand = $uninstallString.UninstallString + " /S"
        if (($uninstallString -like "*.exe*") -and ($uninstallString -notlike "*Msiexec.exe*")) {
        Try{
        Start-ADTProcess -FilePath "cmd.exe" -ArgumentList "/c `"$uninstallCommand`"" -CreateNoWindow
        While (Get-Process -Name "firefox" -ErrorAction SilentlyContinue){ Start-Sleep -Seconds 5 }
        Remove-ADTFile -Path "HKEY_USERS\$currentUserSID\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Mozilla Firefox*"
        Remove-ADTFile -Path "HKEY_USERS\$currentUserSID\Software\\Microsoft\Windows\CurrentVersion\Uninstall\Mozilla Firefox*"
        Write-ADTLogEntry -Message "Uninstalled User installed Firefox(EXE) - $DisplayVer"
        Write-ADTLogEntry -Message "Uninstall Command used - $uninstallCommand"
        }Catch{
        Write-ADTLogEntry -Message "Uninstallation of user installed Firefox failed: $_ "
        }
    }else { Write-ADTLogEntry -Message "No Standard User installed Mozilla Firefox app found." }
    } else {
        Write-ADTLogEntry -Message "No Standard User installed Mozilla Firefox app found."
    }




    $LogU = Get-ADTLoggedOnUser
    $LUname = $LogU.Username #Logged in username

    #Cleanup

    Remove-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Mozilla Firefox*" -Recurse
    Remove-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Mozilla Firefox*" -Recurse
    Set-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\mozilla.org\Mozilla" -Name "CurrentVersion" -Type "String" -Value ''
    Remove-ADTFolder -Path "$envProgramData\Microsoft\Windows\Start Menu\Programs\Mozilla Firefox"
    Remove-ADTFile -Path "$envSystemdrive\Users\Public\Desktop\Firefox.lnk"
    Remove-ADTFile -Path "$envSystemdrive\Users\$LUname\Desktop\Firefox.lnk"
    Remove-ADTFile -Path "$envSystemdrive\Users\$LUname\Desktop\Firefox Private Browsing.lnk"
    Remove-ADTFile -Path "$envSystemdrive\Users\$LUname\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Firefox Private Browsing.lnk"
    Remove-ADTFolder -Path "$envSystemdrive\Program Files\Mozilla Firefox\"


    

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>

    ##==========================
    #<Remove Branding Registry>
    ##==========================
   $ARPs = Get-ADTApplication -Name 'Mozilla Firefox ESR*'
    if (Compare-Version $($adtSession.AppVersion) $ARPs.DisplayVersion "eq"){Write-ADTLogEntry -Message "Firefox app found, Skipping Branding deletion"}
    else{
        Branding-Key -Action "Delete"
    }

}

function Repair-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## If there are processes to close, show Welcome Message with a 60 second countdown before automatically closing.
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -CloseProcessesCountdown 60
    }

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Repair tasks here>


    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI repairs.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transforms', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## <Perform Repair tasks here>


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    # Import the module locally if available, otherwise try to find it from PSModulePath.
    if (Test-Path -LiteralPath "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -PathType Leaf)
    {
        Get-ChildItem -LiteralPath "$PSScriptRoot\PSAppDeployToolkit" -Recurse -File | Unblock-File -ErrorAction Ignore
        Import-Module -FullyQualifiedName @{ ModuleName = "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.5' } -Force
    }
    else
    {
        Import-Module -FullyQualifiedName @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.5' } -Force
    }

    # Open a new deployment session, replacing $adtSession with a DeploymentSession.
    $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
    $adtSession = Remove-ADTHashtableNullOrEmptyValues -Hashtable $adtSession
    $adtSession = Open-ADTSession @adtSession @iadtParams -PassThru
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

# Commence the actual deployment operation.
try
{
    # Import any found extensions before proceeding with the deployment.
    Get-ChildItem -LiteralPath $PSScriptRoot -Directory | & {
        process
        {
            if ($_.Name -match 'PSAppDeployToolkit\..+$')
            {
                Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
                Import-Module -Name $_.FullName -Force
            }
        }
    }

    # Invoke the deployment and close out the session.
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    # An unhandled error has been caught.
    $mainErrorMessage = "An unhandled error within [$($MyInvocation.MyCommand.Name)] has occurred.`n$(Resolve-ADTErrorRecord -ErrorRecord $_)"
    Write-ADTLogEntry -Message $mainErrorMessage -Severity 3

    ## Error details hidden from the user by default. Show a simple dialog with full stack trace:
    # Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop -NoWait

    ## Or, a themed dialog with basic error message:
    # Show-ADTInstallationPrompt -Message "$($adtSession.DeploymentType) failed at line $($_.InvocationInfo.ScriptLineNumber), char $($_.InvocationInfo.OffsetInLine):`n$($_.InvocationInfo.Line.Trim())`n`nMessage:`n$($_.Exception.Message)" -MessageAlignment Left -ButtonRightText OK -Icon Error -NoWait

    Close-ADTSession -ExitCode 60001
}