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
    AppProcessesToClose = @('SelfService','Citrix.DesktopViewer.App')  # Example: @('excel', @{ Name = 'winword'; Description = 'Microsoft Word' })
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
	CustomText = $true
        ForceCountdown = $Defertime
    }
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        $saiwParams.Add('CloseProcesses', $adtSession.AppProcessesToClose)
 
        Show-ADTInstallationWelcome @saiwParams
    }
    Show-ADTInstallationWelcome -CloseProcesses @{Name ="CDViewer"} -Silent
    ## <Perform Pre-Installation tasks here>

    $msg = "Citrix Workspace " + $adtSession.AppVersion + " Installation is in progress" 

     Show-ADTInstallationProgress -StatusMessage $msg

     #Previous version uninstallation - In this case Vendor handles the upgrade scenario correctly = no need for additional uninstallation steps
    #Uninstall-ADTApplication -Name "Microsoft Teams VDI Citrix plugin" -ApplicationType 'MSI'
    #Uninstall-ADTApplication -Name "Citrix Workspace" -ApplicationType 'EXE' -ArgumentList "/silent /noreboot /uninstall /cleanup"

    #Cleanup
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\0269_Citrix_Workspace_23.2.0.38_R01'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\387_Citrix_Workspace_23.9.0_PKG_R2'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\356_Citrix_Workspace_23.5.1.83_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\543_Citrix_Workspace_23.11.1_PKG_R3'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\660_Citrix_Workspace_24.3.1.97_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\819_Citrix_WorkspaceApp_2405.10_PKG_R1' 
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\819_Citrix_Workspace_24.5.10.29_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\819_Citrix_Workspace_24.5.10.29_PKG_R2'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\819_Citrix_WorkspaceApp_2405.10_PKG_R3'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1134_Citrix_Workspace2409_24.9.10.28_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1521_Citrix_Workspace2503_25.3.0.189_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1565_Citrix_Workspace2503_25.3.1.194_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1565_Citrix_Workspace2503_25.3.1.194_PKG_R2'


    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\WOW6432Node\Citrix\Dazzle' -Name 'SelfServiceMode'


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

    Start-ADTProcess -FilePath "$($adtSession.DirFiles)\$($adtSession.InstallerName)" -ArgumentList "/Silent ADDLOCAL=ReceiverInside,ICA_Client,USB,DesktopViewer,AM,SSON,SELFSERVICE,WebHelper /InstallEPAClient=N /InstallMSTeamsPlugin=N /Installzoomplugin=N /FORCE_LAA=1 /includeSSON /ENABLE_SSON=Yes /AutoUpdateCheck=Disabled /EnableCEIP=false /noreboot"

    

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
       Write-ADTLogEntry -Message "Applying user configuration for AMC/AVCC."
        
        ##### User config ###########
        
        ##### For all user related configuration in AMC & AVCC, config should be handled for Default profile also (If it's a Coreapp or It's for Device base Installation)
        #>

        Invoke-ADTAllUsersRegistryAction {
        Set-ADTRegistryKey -Key 'HKCU\Software\Citrix\ICA Client\DPI' -Name 'Enable_DPI' -Value 0 -Type DWord -SID $_.SID
        Remove-ADTRegistryKey -Key 'HKCU\Software\Citrix\Receiver\CtxAccount\088326b561e1cbd5873222b51e8609801f4c2336' -SID $_.SID
        Remove-ADTRegistryKey -Key 'HKCU\Software\Citrix\Receiver\CtxAccount\2b42e8601ac1c0c30e58c981b5d3f832ca8ab10e' -SID $_.SID
    }

    $ProfilePaths = Get-ADTUserProfiles -ExcludeDefaultUser | Select-Object -ExpandProperty 'ProfilePath'

    ForEach ($Path in $ProfilePaths) {
    Remove-ADTFile -Path "$Path\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Citrix Enterprise Browser.lnk"
    }
		
		
    }

    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1949_Citrix_Workspace2503_25.3.10.69_PKG_R1'
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1949_Citrix_Workspace2503_25.3.10.69_PKG_R2'

    #Shortcuts reconfig
    Copy-ADTFile -Path "$($adtSession.DirFiles)\User Guide.pdf" -Destination "$envProgramFilesx86\Citrix\" -Recurse
    Copy-ADTFile -Path "$($adtSession.DirFiles)\Shortcuts\User Guide.lnk" -Destination "$envCommonStartMenuPrograms\Citrix Workspace\" -Recurse
    Copy-ADTFile -Path "$envCommonStartMenuPrograms\Citrix Workspace.lnk" -Destination "$envCommonStartMenuPrograms\Citrix Workspace\" -Recurse
    Remove-ADTFile -Path "$envCommonStartMenuPrograms\Citrix Workspace.lnk"	

    #Hiding Remove\Change button in AddRemovePrograms
    $ARPs = Get-ADTApplication -Name 'Citrix Workspace*'
    ForEach ($ARP in $ARPs){If ($($ARP.PSPath)) {
        Set-ADTRegistryKey -Key "$($ARP.PSPath)" -Name "NoModify" -Value "1" -Type DWord  
        Set-ADTRegistryKey -Key "$($ARP.PSPath)" -Name "NoRemove" -Value "1" -Type DWord}}

    #Registry configurations
    Set-ADTRegistryKey -Key "HKLM\Software\Citrix\Dazzle" -Name "SelfServiceMode" -Value "" -Type String -Wow6432Node 
    Set-ADTRegistryKey -Key "HKLM\Software\Citrix\AuthManager" -Name "EdgeChromiumEnabled" -Value "true" -Type String -Wow6432Node 

    Set-ADTRegistryKey -Key "HKLM\Software\Citrix\ICA Client\Engine\Configuration\Advanced\Modules\VDCSCOMT" -Name "DriverName" -Value "CiscoMeetingsCitrixPlugin.dll" -Type String -Wow6432Node 
    Set-ADTRegistryKey -Key "HKLM\Software\Citrix\ICA Client\Engine\Configuration\Advanced\Modules\VDCSCOMT" -Name "DriverNameWin16" -Value "CiscoMeetingsCitrixPlugin.dll" -Type String -Wow6432Node
    Set-ADTRegistryKey -Key "HKLM\Software\Citrix\ICA Client\Engine\Configuration\Advanced\Modules\VDCSCOMT" -Name "DriverNameWin32" -Value "CiscoMeetingsCitrixPlugin.dll" -Type String -Wow6432Node

    Set-ADTRegistryKey -Key "HKLM\Software\Citrix\ICA Client\Engine\Configuration\Advanced\Modules\VDCSCOTM" -Name "DriverName" -Value "CiscoTeamsCitrixPlugin.dll" -Type String -Wow6432Node 
    Set-ADTRegistryKey -Key "HKLM\Software\Citrix\ICA Client\Engine\Configuration\Advanced\Modules\VDCSCOTM" -Name "DriverNameWin16" -Value "CiscoTeamsCitrixPlugin.dll" -Type String -Wow6432Node
    Set-ADTRegistryKey -Key "HKLM\Software\Citrix\ICA Client\Engine\Configuration\Advanced\Modules\VDCSCOTM" -Name "DriverNameWin32" -Value "CiscoTeamsCitrixPlugin.dll" -Type String -Wow6432Node


    
    ##====================
    #<Branding Registry>
    ##====================

    $ARPs = Get-ADTApplication -Name 'Citrix Workspace 2*'
    if (Compare-Version $($adtSession.AppVersion) $ARPs.DisplayVersion "eq") {
        Branding-Key -Action "Create"
        If($Platform -eq "RAPPS"){ Set-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\$($adtSession.AppVendor)_$($adtSession.AppName)_PKG" -Name "Platform" -Value "AMC & AVC & RAPPS" -Type String }
    }else{Write-ADTLogEntry -Message "CWA app not found, Skipping Branding creation"}

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
    Show-ADTInstallationWelcome -CloseProcesses @{Name ="SelfService"},@{Name ="CDViewer"} -Silent

    $msg = "Citrix Workspace " + $adtSession.AppVersion + " Uninstallation is in progress" 

    Show-ADTInstallationProgress -StatusMessage $msg

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

    Uninstall-ADTApplication -Name "Citrix Workspace" -ApplicationType 'EXE' -ArgumentList "/silent /noreboot /uninstall /cleanup"
    

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>

    

    #Cleanup 
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\Software\WOW6432Node\Citrix\Dazzle' -Name 'SelfServiceMode'
    Remove-ADTFolder -Path "$envCommonStartMenuPrograms\Citrix Workspace"
    Remove-ADTFile -Path "$envProgramFilesx86\Citrix\User Guide.pdf"
    
    Remove-ADTFile -Path "$envProgramData\Microsoft\Windows\Start Menu\Programs\Citrix Workspace" -Recurse -ErrorAction SilentlyContinue    
	
    ##==========================
    #<Remove Branding Registry>
    ##==========================

    $ARPs = Get-ADTApplication -Name 'Citrix Workspace 2*'
    if (Compare-Version $($adtSession.AppVersion) $ARPs.DisplayVersion "eq") {Write-ADTLogEntry -Message "CWA app found, Skipping Branding deletion"}
    else{Branding-Key -Action "Delete"}

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
