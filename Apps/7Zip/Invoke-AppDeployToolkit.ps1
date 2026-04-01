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
    AppProcessesToClose = @('7zFM')  # Example: @('excel', @{ Name = 'winword'; Description = 'Microsoft Word' })
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
    DeployAppScriptDate = '2025-10-10'
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

    ## Show Welcome Message, close processes if specified, allow up to 1 deferrals, verify there is enough disk space to complete the install, and persist the prompt.
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


    #Previous version uninstallation
    Uninstall-ADTApplication -Name "7-Zip" -ApplicationType 'MSI'
    Uninstall-ADTApplication -Name "7-Zip" -ApplicationType 'EXE' -ArgumentList "/S"

    #Cleanup
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\360_Igor Pavlov_7-Zip_23.01_PKG_R1' 
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\710_IgorPavlov_7-Zip_24.07_PKG_R1' 
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AMC\Packages\710_IgorPavlov_7-Zip_24.07_PKG_R2' 
    Remove-ADTRegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1051_IgorPavlov_7-Zip_24.09_PKG_R1' 



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


    Start-ADTMsiProcess -Action 'Install' -FilePath "$($adtSession.DirFiles)\$($adtSession.InstallerName)"
    

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
		
        #Registry customizations
    Invoke-ADTAllUsersRegistryAction {
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip' -Name 'Path' -Value "$envProgramFiles\7-Zip\" -Type String -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip' -Name 'Path64' -Value "$envProgramFiles\7-Zip\" -Type String -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\Compression' -Name 'Archiver' -Value "7z" -Type String -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'FolderShortcuts' -Type Binary -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'FolderHistory' -Value (0x00,0x00) -Type Binary -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'PanelPath0' -Value '' -Type String -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'PanelPath1' -Value '' -Type String -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'FlatViewArc0' -Value '0' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'FlatViewArc1' -Value '0' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'ListMode' -Value '771' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'Position' -Value (0x05,0x00,0x00,0x00,0xeb,0x00,0x00,0x00,0xa5,0x05,0x00,0x00,0xe2,0x03,0x00,0x00,0x00,0x00,0x00,0x00) -Type Binary -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'Panels' -Value (0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xc6,0x02,0x00,0x00) -Type Binary -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'Editor' -Value "$envSystem32Directory\notepad.exe" -Type String -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'ShowDots' -Value '0' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'ShowRealFileIcons' -Value '1' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'FullRow' -Value '1' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'ShowGrid' -Value '1' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'SingleClick' -Value '0' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'AlternativeSelection' -Value '0' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM' -Name 'ShowSystemMenu' -Value '1' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\FM\Columns' -Name 'RootFolder' -Value (0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x04,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0xa0,0x00,0x00,0x00) -Type Binary -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\Options' -Name 'MenuIcons' -Value '1' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\Options' -Name 'ContextMenu' -Value '1073758071' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\Options' -Name 'WorkDirType' -Value '0' -Type DWord -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\Options' -Name 'WorkDirPath' -Value '' -Type String -SID $_.SID
        Set-ADTRegistryKey -Key 'HKCU\SOFTWARE\7-Zip\Options' -Name 'TempRemovableOnly' -Value '0' -Type DWord -SID $_.SID
    }

    #File associations (FileType-IconIndex)
    $Table = @('7z-0','zip-1','rar-3','001-9','cab-7','iso-8','tar-13','bz2-2','bzip2-2','tbz2-2','tbz-2','gz-14','gzip-14','tgz-14','tpz-14','z-5','lzh-6','arj-4')
    $FileTypes = Foreach ($Object in $Table){
        $Properties = $Object.Split("-")
        [PSCustomObject]@{
            FileType = $Properties[0]
            IconIndex = $Properties[1]
        }
    }

    Foreach ($Object in $FileTypes){
        Set-ADTRegistryKey -Key "HKEY_CLASSES_ROOT\.$($Object.FileType)" -Name "(Default)" -Value "7-Zip.$($Object.FileType)"
        Set-ADTRegistryKey -Key "HKEY_CLASSES_ROOT\7-Zip.$($Object.FileType)" -Name "(Default)" -Value "$($Object.FileType) Archive" 
        Set-ADTRegistryKey -Key "HKEY_CLASSES_ROOT\7-Zip.$($Object.FileType)\DefaultIcon" -Name "(Default)" -Value "$envProgramFiles\7-Zip\7z.dll,$($Object.IconIndex)"
        Set-ADTRegistryKey -Key "HKEY_CLASSES_ROOT\7-Zip.$($Object.FileType)\shell\open\command" -Name "(Default)" -Value """$envProgramFiles\7-Zip\7zFM.exe"" ""%1"""
    }

		
    }
    Remove-ADTFile -Path "$envCommonStartMenuPrograms\7-Zip\7-Zip Help.lnk"

    
    ##====================
    #<Branding Registry>
    ##====================

   $ARPs = Get-ADTApplication -Name '7-Zip*'
    if (Compare-Version $($adtSession.AppVersion) $ARPs.DisplayVersion "eq") {
        Branding-Key -Action "Create"
        If($Platform -eq "RAPPS"){ Set-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\$($adtSession.AppVendor)_$($adtSession.AppName)_PKG" -Name "Platform" -Value "AMC & AVC & RAPPS" -Type String }
    }else{Write-ADTLogEntry -Message "7zip app not found, Skipping Branding creation"}
    

    
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

    Show-ADTInstallationWelcome -CloseProcesses @{Name ="7zFM"} -Silent

    ## <Perform Pre-Uninstallation tasks here>

    
    Uninstall-ADTApplication -Name "7-Zip" -ApplicationType 'MSI'
    Uninstall-ADTApplication -Name "7-Zip" -ApplicationType 'EXE' -ArgumentList "/S"

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

    
    #Cleanup
    Remove-ADTFolder -Path "$envProgramFiles\7-Zip"
    Remove-ADTFolder -Path "$envProgramFilesX86\7-Zip"

    #File associations
    $Table = @('7z-0','zip-1','rar-3','001-9','cab-7','iso-8','tar-13','bz2-2','bzip2-2','tbz2-2','tbz-2','gz-14','gzip-14','tgz-14','tpz-14','z-5','lzh-6','arj-4')
    $FileTypes = Foreach ($Object in $Table){
        $Properties = $Object.Split("-")
        [PSCustomObject]@{
            FileType = $Properties[0]
            IconIndex = $Properties[1]
        }
    }

    Foreach ($Object in $FileTypes){
        Remove-ADTRegistryKey -Key "HKEY_CLASSES_ROOT\.$($Object.FileType)" -Recurse
        Remove-ADTRegistryKey -Key "HKEY_CLASSES_ROOT\7-Zip.$($Object.FileType)" -Recurse
    }



    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>

    ##==========================
    #<Remove Branding Registry>
    ##==========================

    $ARPs = Get-ADTApplication -Name '7-Zip*'
    if (Compare-Version $($adtSession.AppVersion) $ARPs.DisplayVersion "eq") {Write-ADTLogEntry -Message "7zip app found, Skipping Branding deletion"}
    else{ Branding-Key -Action "Delete" }

    
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