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
    AppArch = 'x64'
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppProcessesToClose = @('ms-teams','teams')  # Example: @('excel', @{ Name = 'winword'; Description = 'Microsoft Word' })
    AppScriptVersion = '1.0.0'
    AppScriptDate = '###DATETIME###'
    AppScriptAuthor = 'IntuneAppFactory'
    RequireAdmin = $true
    APPID_Short = ""
	InstallerName = '###SETUPFILENAME###'
    AppID = '###APPID###'
    FamilyID = '3545'
    Platform = 'AMC and AVC'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ""
    InstallTitle = " "

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters = $PSBoundParameters
    DeployAppScriptVersion = '4.1.5'
    DeployAppScriptDate = '2026-2-11'     # Do not modify the DATE here, it should be 2026-2-11
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
	
	Get-ChildItem -Path "$($adtSession.DirFiles)" -Recurse -ErrorAction SilentlyContinue | Unblock-File
	
	##============================
	## Uninstalling Classic Teams
	##============================
	
	$TeamsClassic = Test-Path "$envProgramFiles86\Microsoft\Teams\Update.exe"
    
    if($TeamsClassic)
    {
        Write-ADTLogEntry -Message "Machine based Classic Teams is installed. Hence, proceeding with the uninstallation..."
          
        # Function to uninstall Teams Classic
        function Uninstall-TeamsClassic($TeamsPath) 
        {
			try{
				$process = Start-ADTProcess -FilePath "$TeamsPath\Update.exe" -ArgumentList "--uninstall /s" -PassThru -Wait -ErrorAction STOP
				if($process.ExitCode -ne 0) {
					Write-Error "Uninstallation failed with exit code $($process.ExitCode)."	
				}
			}
			catch{
                Write-Error $_.Exception.Message
			}
        }
    }
    
    # Remove Teams Machine-Wide Installer
    Write-ADTLogEntry -Message "Removing Teams Machine-wide Installer..."

    #Uninstall Any Existing Versions of Teams Machine-Wide Installer (MSI)
    Uninstall-ADTApplication -FilterScript {$_.DisplayName -eq 'Teams' -and $_.Publisher -match 'Microsoft Corporation'} -ArgumentList "/qn" -LogFileName "PreviousVersion_MicrosoftTeams_ClassicWideInstaller" -ErrorAction SilentlyContinue
    Uninstall-ADTApplication -FilterScript {$_.DisplayName -eq 'Teams Machine-Wide Installer'} -ArgumentList "/qn" -LogFileName "PreviousVersion_MicrosoftTeams_ClassicWideInstaller" -ErrorAction SilentlyContinue
    Uninstall-ADTApplication -FilterScript {$_.DisplayName -eq 'Microsoft Teams'} -ArgumentList "/qn" -LogFileName "PreviousVersion_MicrosoftTeams_ClassicWideInstaller" -ErrorAction SilentlyContinue
    Uninstall-ADTApplication -FilterScript {$_.DisplayName -eq 'Microsoft Teams Classic'} -ArgumentList "/qn" -LogFileName "PreviousVersion_MicrosoftTeams_ClassicWideInstaller" -ErrorAction SilentlyContinue
    Uninstall-ADTApplication -FilterScript {$_.DisplayName -match 'Microsoft_Teams'} -ArgumentList "/qn" -LogFileName "PreviousVersion_MicrosoftTeams_ClassicWideInstaller" -ErrorAction SilentlyContinue
    
    #### Remove desktop entry / Quicklaunch / appdata ####
    $UserProfiles = Get-ADTUserProfiles | Select-Object -ExpandProperty 'ProfilePath' 
    foreach($ProfilePath in $UserProfiles)
    {
        Remove-ADTFile -Path "$ProfilePath\Desktop\Microsoft Teams.lnk" -Recurse -ErrorAction SilentlyContinue
		Remove-ADTFile -Path "$ProfilePath\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk" -Recurse -ErrorAction SilentlyContinue
		Remove-ADTFile -Path "$ProfilePath\AppData\Local\Microsoft\TeamsPresenceAddin" -Recurse -ErrorAction SilentlyContinue
		Remove-ADTFile -Path "$ProfilePath\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Corporation\Microsoft Teams.lnk" -Recurse -ErrorAction SilentlyContinue
    }
	
	Remove-ADTFile -Path "$envPublic\Desktop\Microsoft Teams.lnk" -ErrorAction SilentlyContinue
	Remove-ADTFile -Path "$envProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk" -ErrorAction SilentlyContinue
	
	Remove-ADTFile -Path "$env:SystemDrive\Airwatch\0018_Microsoft_Teams_1.3.0.13565_EN_R01_Install.log" -ErrorAction SilentlyContinue
	
	Unregister-ScheduledTask CreateMSTeamsFirewallRule -Confirm:$false -ErrorAction SilentlyContinue
    
    Remove-NetFirewallRule -DisplayName "Teams.exe*" -ErrorAction SilentlyContinue

    if(Test-Path -Path "${ENV:ProgramFiles(x86)}\Microsoft\Teams")
    {
        $Path1 = "${ENV:ProgramFiles(x86)}\Microsoft\Teams"
        Remove-ADTFolder $Path1 -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 10
	
    ##Removing previous branding:
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\0012_Microsoft_Teams_1.3.0.4461_EN_R01' -ErrorAction SilentlyContinue
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\0018_Microsoft_Teams_1.3.0.13565_EN_R01' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\0036_Microsoft_Teams_1.3.0.26064_EN_R01' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\403_Microsoft_NewTeams_23285.3607.2525.937_PKG_R1' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\403_Microsoft_NewTeams_23285.3607.2525.937_PKG_R2' -ErrorAction SilentlyContinue
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\403_Microsoft_NewTeams_23285.3607.2525.937_PKG_R3' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\403_Microsoft_NewTeams_23285.3607.2525.937_PKG_R4' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\403_Microsoft_NewTeams_23285.3607.2525.937_PKG_R5' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\587_Microsoft_NewTeams_24074.2321.2810.3500_PKG_R1' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\797_Microsoft_NewTeams_24215.1007.3082.1590_PKG_R1' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\797_Microsoft_NewTeams_24215.1007.3082.1590_PKG_R2' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\2141_Microsoft_Teams_25198.1112.3855.2900_PKG_R1' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\2524_Microsoft_Teams_25255.703.3978.7153_PKG_R1' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\2838_Microsoft_Teams_25275.2601.4002.2815_PKG_R1' -ErrorAction SilentlyContinue
	Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\3352_Microsoft_Teams_25306.804.4102.7193_PKG_R1' -ErrorAction SilentlyContinue
	
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

    #Main Installation
    #$AppSetupFileName = Get-ChildItem -Path $($adtSession.DirFiles) -File -Recurse | Where-Object { $PSItem.Extension -like ".msix"} | Sort-Object -Property "LastModified" -Descending | Select-Object -First 1
    
	$version = Get-Appxpackage -Allusers -Name MSteams | Select-Object -ExpandProperty Version
    if(($version -lt $adtSession.AppVersion))
	{
    	if($null -eq $version){
        Write-ADTLogEntry -Message "No version of teams installed in the device. Hence, proceeding with upgradation Micosoft Teams application."
        }else{
    	Write-ADTLogEntry -Message "Installed Version ($version) is less than packaged version. Hence, proceeding with upgradation Micosoft Teams application."
		}   
                
		Stop-Process -Name "ms-teams" -Force -ErrorAction SilentlyContinue
		
		Set-NonRemovableAppsPolicy -Online -PackageFamilyName MSTeams_8wekyb3d8bbwe -NonRemovable 0 -ErrorAction SilentlyContinue
		
		Get-AppxPackage "*msteams*" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
		
		Start-Sleep -Seconds 20
		
		Set-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value "1" -Type DWORD
		
		Start-ADTProcess -FilePath "$($adtSession.DirFiles)\teamsbootstrapper.exe" -ArgumentList "-p -o `"$($adtSession.DirFiles)\$($adtSession.InstallerName)`"" -ErrorAction SilentlyContinue -WindowStyle Hidden
		
		Start-Sleep -Seconds 30
		
		Set-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value "0" -Type DWORD -ErrorAction SilentlyContinue
		
		Start-Sleep -Seconds 10
		
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
			Write-ADTLogEntry -Message "Applying user configuration for AMC/AVCC."
			
			##### User config ###########
			
			##### For all user related configuration in AMC & AVCC, config should be handled for Default profile also (If it's a Coreapp or It's for Device base Installation)
			#Import-RegistryFileUser $adtSession.appName """$($adtSession.DirFiles)\HKCUTeams.reg"""
            Start-ADTProcess -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File ""$($adtSession.DirSupportFiles)\Import-Registry.ps1"" -RegFile ""$($adtSession.DirFiles)\HKCUTeams.reg"" -CurrentUser" -WindowStyle "Hidden"
		}
		
		Show-ADTInstallationPrompt -Message """Microsoft Teams"" application is updated. It can be access from Start Menu using ""Microsoft Teams"" icon." -ButtonRightText 'Ok' -Icon Information -Nowait -Timeout 30
	}
    else{
		Write-ADTLogEntry -Message "Installed Version ($version) is greater than or equal to the packaged version."
	}
	
    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>

    ##=====================
    ## Create Branding Key
    ##=====================
    $version = Get-Appxpackage -Allusers -Name MSteams | Select-Object -ExpandProperty Version
    if(([version]$version -eq [version]$adtSession.AppVersion))
    {
	    Branding-Key -Action "Create"    
    
	    If($Platform -eq "RAPPS"){ Set-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\$($adtSession.AppVendor)_$($adtSession.AppName)_PKG" -Name "Platform" -Value "AMC & AVC & RAPPS" -Type String }
    }

    Write-ADTLogEntry -Message "Starting Microsoft Teams after installation."
    $runteams = Start-ADTProcessAsUser -FilePath "powershell.exe" -ArgumentList "-executionpolicy bypass -file `"$($adtSession.DirFiles)\AutoLaunch_Teams.ps1`" -InstalledVersion $($adtSession.AppVersion)" -WindowStyle 'Hidden' -Passthru    
    If ($runteams.ExitCode -eq "0"){
      Write-ADTLogEntry -Message "Microsoft Teams is started successful"   
    }else {
      Write-ADTLogEntry -Message "Starting Microsoft Teams failed"     
    }
  
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
    <#if($Nodefer){
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
    }#>
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -Silent
    }

    ## <Perform Pre-Uninstallation tasks here>

    

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

    Set-NonRemovableAppsPolicy -Online -PackageFamilyName MSTeams_8wekyb3d8bbwe -NonRemovable 0 -ErrorAction SilentlyContinue
    
	$test = Get-AppxPackage -name "*MSTeams*"
    foreach ($app in $test)
	{
		Remove-AppxPackage -Package $app.PackageFullname
    }
		
    Get-AppxPackage "*msteams*" -AllUsers | Remove-AppxPackage -AllUsers
 
    Start-Sleep -Seconds 20 
	
    Remove-ADTRegistryKey -Key "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\Teams" -Recurse -ErrorAction SilentlyContinue
    
    Set-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value "1" -Type DWORD

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>

    ##=====================
    ## Remove Branding Key
    ##=====================
    $version = Get-Appxpackage -Allusers -Name MSteams | Select-Object -ExpandProperty Version
    if(($version -eq $adtSession.AppVersion))
    {}else{
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