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
    AppProcessesToClose = @(' ')  # Example: @('excel', @{ Name = 'winword'; Description = 'Microsoft Word' })
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
    DeployAppScriptDate = '2025-02-11'
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
 
        #Show-ADTInstallationWelcome @saiwParams
    }

    ## <Perform Pre-Installation tasks here>
	
    Get-ChildItem -Path "$($adtSession.DirFiles)" -Recurse -ErrorAction SilentlyContinue | Unblock-File

    #========================================================================
    ##Previous or laterst VC++ x64 if present:
    #========================================================================

    Remove-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\1947_MS_VCRedis2015to2022_14.42.34433.0_PKG_R1" -ErrorAction SilentlyContinue
    
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
    
    $ARP = Get-ADTApplication -Name 'Microsoft Visual C++ * Redistributable (x64)*' | Where-Object { $_.DisplayVersion -like '14.*'  -and $_.SystemComponent -ne "1" }
    If([version]$ARP.DisplayVersion -lt [version]$($adtSession.AppVersion))
    {
        Start-ADTProcess -FilePath "$($adtSession.DirFiles)\$($adtSession.InstallerName)" -ArgumentList "/S /norestart" -WindowStyle 'Hidden' -IgnoreExitCodes '3010,1641'
    }
    else
    {
        Write-ADTLogEntry -message "Higher or same version of the application is installed. Skipping the installation."
    }
   
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
        #Write-ADTLogEntry -Message "Applying user configuration for AMC/AVCC."
        
        ##### User config ###########
        
        ##### For all user related configuration in AMC & AVCC, config should be handled for Default profile also (If it's a Coreapp or It's for Device base Installation)
        #>
		
        }
    
    # Hiding Remove button in ARP:
    $ARPs = Get-ADTApplication -Name "Microsoft Visual C++ * Redistributable (x64)*" | Where-Object { $_.DisplayVersion -like '14.*'  -and $_.SystemComponent -ne "1" }
        ForEach ($ARP in $ARPs)
        {
            If ($($ARP.PSPath)) 
            {
                Set-ADTRegistryKey -Key "$($ARP.PSPath)" -Name "NoModify" -Value "1" -Type DWord  
                Set-ADTRegistryKey -Key "$($ARP.PSPath)" -Name "NoRemove" -Value "1" -Type DWord
            }
        }

    ##====================
    #<Branding Registry>
    ##====================

    $ARP = Get-ADTApplication -Name 'Microsoft Visual C++ * Redistributable (x64)*' | Where-Object { $_.DisplayVersion -like '14.*' -and $_.SystemComponent -ne "1" }
    if (Compare-Version $($adtSession.AppVersion) $ARP.DisplayVersion "eq")
    {
        Branding-Key -Action "Create"
        If($Platform -eq "RAPPS"){ Set-ADTRegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\AllianzPackages\$($adtSession.AppVendor)_$($adtSession.AppName)_PKG" -Name "Platform" -Value "AMC & AVC & RAPPS" -Type String }
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

    if($NoDefer){
      $Defertime = 900
      $DeferCount = 0  
     
    }else{
        $Defertime = 900
        $DeferCount = 1
    }
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
       # Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -AllowDefer -DeferTimes $DeferCount -ForceCountdown $DeferTime
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

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>
        
        Branding-Key -Action "Delete"
    
    
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
# SIG # Begin signature block
# MIIigQYJKoZIhvcNAQcCoIIicjCCIm4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAzKes2eacZpc7I
# nEFvJIBBgUqCNav2P5wmdBz4j+1vpqCCHK4wggQUMIIC/KADAgECAgQQAztrMA0G
# CSqGSIb3DQEBCwUAMEUxCzAJBgNVBAYTAkRFMRAwDgYDVQQKDAdBbGxpYW56MSQw
# IgYDVQQDDBtBbGxpYW56IEluZnJhc3RydWN0dXJlIENBIFYwHhcNMjUwMzEyMDcz
# MjM0WhcNMjcwMzEyMDczMjM0WjA8MQswCQYDVQQGEwJERTEQMA4GA1UECgwHQWxs
# aWFuejEbMBkGA1UEAwwSV1BTX0FQUFNfUGFja2FnaW5nMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAp2jGJrEwfnn0ii6d0v1/mZfvjw4godWtF/u+0Sxo
# 4LV37NAUIE7ntLPn7D4dvuBpVuvJeEPBEmn7pgLgsKZXDfXDnz+6JRotu+AFNi1J
# +xUlwalAlsojexe6aJHCWxFNeLwdO12v1MaAw/22AKTx/MZAU9/ckCKj6SqE/IJZ
# lPkTxe2OCTB1JZvCc5/gs6EhCAvwGTbZy3KSiKiXYZoyPvl8IlGolVJbpYgZ5Gr/
# d13FnRUKiLqOF5ykQ+ZUE24cFfq3TJAHdS1ld7Y4eEdH7f4pA0Lpa0g6+l3CsOaV
# MueMSnfC4u37y8dHkZeDwcd1z7i1Qujp1xGf/7za3VnJvwIDAQABo4IBEzCCAQ8w
# HQYDVR0OBBYEFCpHadszhB+Ki9+CYKU6dDbmQeFgMA4GA1UdDwEB/wQEAwIHgDAT
# BgNVHSUEDDAKBggrBgEFBQcDAzAbBgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMD
# MDsGCCsGAQUFBwEBBC8wLTArBggrBgEFBQcwAYYfaHR0cDovL3Jvb3RjYS5hbGxp
# YW56LmNvbS9vY3NwLzBvBgNVHR8EaDBmMDGgL6AthitodHRwOi8vcm9vdGNhLmFs
# bGlhbnouY29tL2NybC9JbmZyYUNBLVYuY3JsMDGgL6AthitodHRwOi8vcm9vdGNh
# LmluZC5hbGxpYW56L2NybC9JbmZyYUNBLVYuY3JsMA0GCSqGSIb3DQEBCwUAA4IB
# AQB2dD0t9o8W7n18NyFGEmOux0XCvt9s/DacEmgbadQZDUxM1TWQB8PZ5yzbRgsD
# livpi1h9YxZuWBGpyiwQJzOvVYS1ptcw8GEWkcPiUkEzOt/JyO0g8k29kdXdbLe/
# WR/gFLORZmYPA/lbhFGtsrGtaCef5uGFJwowPhh+bO8i9lZClRlwGSsqALqizLmM
# cDJrX5sxGG9RmMlNgLn1Yt0kaQydNFx/YTV568cgeslvHvWiXJ4GqCkeWMIPFpax
# ctW1BgzcDkeF5UnHN2nvuFbaKCN3/EPhgD19G6QMTYsCx5ZJ5nLW/4u3x5oEkM4G
# SZGq6eVq9sCj/b8LfZeGh2mYMIIFWDCCA0CgAwIBAgIBCTANBgkqhkiG9w0BAQsF
# ADA9MQswCQYDVQQGEwJERTEQMA4GA1UEChMHQWxsaWFuejEcMBoGA1UEAxMTQWxs
# aWFueiBSb290IENBIElJSTAeFw0xNTA0MjkwOTEzMDJaFw0zMDA0MjUwOTEzMDJa
# MEUxCzAJBgNVBAYTAkRFMRAwDgYDVQQKDAdBbGxpYW56MSQwIgYDVQQDDBtBbGxp
# YW56IEluZnJhc3RydWN0dXJlIENBIFYwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQDPROja9dPfvzzYV7oiiCQ06BCwbEr0QBhYdxQDa9bCi8h98Sg//ARQ
# 308eJ1QS8HVNa0XzP5eqDmvjNf0mJvjp4MWqBkHxyliLjNWYjX7zAZsRGgqLpZpe
# cwiFGKfy+46WrVCpL9mEIWc1I6C17BZKeIzzhq0dl4KFpKaoLcDJc4t97/ulUJvC
# ztFKSMjOF2U7+FCL2QuXiAfOtHT0bH+dGpcg+wFsIVOxpYIZ50p4i/CKusYrQqo9
# BiDFtVjT3J8suhAN8iqCh0pLGE6LCC/W+wZgnZtJF7BbOwz7F/xTNitTvvZ6YK/c
# AOBI3cFZHBzNBSTzqGWx4+SZ9cO1iGIBAgMBAAGjggFZMIIBVTAOBgNVHQ8BAf8E
# BAMCAYYwHQYDVR0OBBYEFHG9sutEhiEEN7BuC3TAjPpdhO3QMB8GA1UdIwQYMBaA
# FBpX2GOBsZ8a/os2bNCngGhHLnr5MBIGA1UdEwEB/wQIMAYBAf8CAQAwOgYDVR0f
# BDMwMTAvoC2gK4YpaHR0cDovL3Jvb3RjYS5hbGxpYW56LmNvbS9jcmwvcm9vdGNh
# My5jcmwwgbIGA1UdIASBqjCBpzCBpAYJKwYBBAG3dx4gMIGWMCoGCCsGAQUFBwIB
# Fh5odHRwOi8vcm9vdGNhLmFsbGlhbnouY29tL2NwczMwaAYIKwYBBQUHAgIwXDAW
# Fg9BbGxpYW56IEdlcm1hbnkwAwIBARpCVGhpcyBDZXJ0aWZpY2F0ZSBpcyBpc3N1
# ZWQgYnkgQWxsaWFueiBSb290IENBIElJSSwgQWxsaWFueiBHZXJtYW55MA0GCSqG
# SIb3DQEBCwUAA4ICAQCzq+l+6m9LA7hXS43xlNnYvX1MReAUmK05zIIipCfWfSK0
# f5ZFcqrHAbHI/rxflM88yCepFPpVqwkL2sOBAtlvLmyLMRsrOunT8hOiDdcPyQVh
# GHAE1awBg8lU45xupsifuYNr+7+mfoHFhnI15f/ADy3zlnj1EsSESL30YPWK3PyN
# QQGU8PG65eRZGvceGvQV+dn2j1isy1fesFnsoFjgtfS2xoxhYlm9EGwkQKOzWK9y
# mtD3qHefHykq8RfYfGqF04r3TRVGz0mjOKElzk1kNxv64H8xI3u4PzsWYRSLZkAo
# IxvTWQKb/mCXRkBYvTN53zG186lfNKvoaCfiDJDYVTs1yNTDHP0DgQzbmbtfvDNj
# 9itUZ3qIQaXxyyXVSt57ixj+HbwwNMJOQRVa5jR3AqqiLWMQ3R01vFP27C9SdSQa
# pm17xb9CYZZwhq5qcViC9lD/Nxc/uAu2oB4Q6YpwWWZWTAXXLYyIjK+KCvRxNQW/
# P1jz2T9XeKnt28uY2R5pxdy/SyCV1Il08cqIqcHDGfdRmG8teg51IHRdzDWFmKRo
# 0dvuEG2HZkdz3c808DCXicVVHLedyhLqzvUMdNOB2YuT8HsrJ9au0b6ZiUr68HtH
# ObCowP00BXpLmCmHCjxp9QEZhnwmk7H3R18SSvbeg0iYACOo7ThQJG0LPZ0GLjCC
# BY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290
# IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE9
# 8orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9S
# H8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g
# 1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RY
# jgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgD
# EI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNA
# vwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDg
# ohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQA
# zH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOk
# GLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHF
# ynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gd
# LfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
# FOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNy
# dDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkq
# hkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7
# IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/5
# 9PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0
# POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISf
# b8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhU
# LSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDCCBrQwggScoAMCAQICEA3H
# rFcF/yGZLkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEh
# MB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1MDUwNzAwMDAw
# MFoXDTM4MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFt
# cGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2tjQ2UtZmWgyxU
# 7UNqEY81FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWCWgzbNfiR
# +2fkHUiljNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vtLa4+gKPsYfwE
# u7EEbkC9+0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0XaF9DPfNBKS7Za
# zch8NF5vp7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhxKTVVgtmUPAW3
# 5xUUFREmDrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXKFifinT7zL2gd
# FpBP9qh8SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x5HHKS+rq
# BvKWxdCyQEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F20HHfIY4/6vH
# espYMQmUiote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQyogxG9QE
# PHrPV6/7umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u70EwgWbVRSX1
# Wd4+zoFpp4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczsG7ZrIGNTAgMB
# AAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTvb1NK6eQG
# fHrK4pBW9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAO
# BgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEE
# azBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYB
# BQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0
# ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYG
# Z4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAF877FoAc/gc9
# EXZxML2+C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI9NAzaoQk
# 97frPBtIj+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ3essBS3q8nL2
# UwM+NMvEuBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qKtntujB71
# WPYAgwPyWLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I+ZI2rVQf
# jXQA1WSjjf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q17r0z0noD
# js6+BFo+z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9M+MtucVGyOxi
# Df06VXxyKkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSmE+9JGYxOGLS/
# D284NHNboDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlHqhpB/8Ml
# uDezooIs8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7GELH3IdvG
# 2XlM9q7WP/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKdvlarEvf8EA+8
# hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggbtMIIE1aADAgECAhAKgO8YS43xBYLR
# xHanlXRoMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5E
# aWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1l
# U3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAwMDAw
# WhcNMzYwOTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNl
# cnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1NiBSU0E0MDk2IFRpbWVz
# dGFtcCBSZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEA0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfMGUIwYzKomd8U1nH7C8Dr
# 0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFPJIDZHhAqlUPt281mHrBb
# ZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMUNg7MOLxI6E9RaUueHTQK
# WXymOtRwJXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjKs3SKO1QNUdFd2adw44wD
# cKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8odbkqoK+lJ25LCHBSai25
# CFyD23DZgPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK40uhktzUd/Yk0xUvhDU6l
# vJukx7jphx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk12hE5FVs9HVVWcO5J4dV
# mVzix4A77p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2hSgctaepZTd0ILIUbWuh
# KuAeNIeWrzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6CtjuuVHJOVoIJ/DtpJRE7C
# e7vMRHoRon4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT3pXWETTJkhd76CIDBbTR
# ofOsNyEhzZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A9/z7eacCAwEAAaOCAZUw
# ggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx7f391/ORcWMZUEPPYYzo
# MB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIH
# gDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYI
# KwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZR
# aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGlt
# ZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBS
# oFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRp
# bWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgG
# BmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBAGUqrfEcJwS5
# rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP2AGr181o2YWPoSHz9iZE
# N/FPsLSTwVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7YXwB
# D9R0oU62PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75ZSpbh1oipOhcUT8lD8QA
# GB9lctZTTOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihsQyfFg5fxUFEp7W42fNBV
# N4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQJmmrJTV3Qhtfparz+BW6
# 0OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz0BZwhB9WOfOu/CIJnzkQ
# TwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8MmB10nfldPF9SVD7weCC
# 3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjFBtXVLcKtapnMG3VH3EmA
# p/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJVxwC+UpX2MSey2ueIu9T
# HFVkT+um1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFlTxq25+T4QwX9xa6ILs84
# ZPvmpovq90K8eWyG2N01c4IhSOxqt81nMYIFKTCCBSUCAQEwTTBFMQswCQYDVQQG
# EwJERTEQMA4GA1UECgwHQWxsaWFuejEkMCIGA1UEAwwbQWxsaWFueiBJbmZyYXN0
# cnVjdHVyZSBDQSBWAgQQAztrMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEID/ii1g8OyDX
# y4p28VWNrljlkP/X2pgZDjG/Pd7Y7gSAMA0GCSqGSIb3DQEBAQUABIIBAAhdQpIc
# YNA0cOdikZtthHDalEIty+qRA4sfMXvmoptkcCYU5c44rarYkMHwfNaf3NrQCWT+
# 5HqvMJApihG2BwK1dF3RvwNPBh1Z+gzwgbj2MtqTFEHYyJuIaDzRyA7SO7JJ4IrP
# P3y/NZHjrcjtOUwdmdNSNWW/lXDKMADInlzNXPCywxEVbvXy9MrfDV8H/bXZ7gAA
# b5jyUi68hkIV7FF9K4NAiT5GgiTdOA+OzsUxdmMNWTVZzayHtU+SFgplVcDAFTxE
# 2/M1fOWlGNVvQfLJbFb9BHUYkSanIwci31hijvrHicQdCuJ9nwB4Ph7kfQF5CatQ
# hfh4KkOuYP7os4WhggMmMIIDIgYJKoZIhvcNAQkGMYIDEzCCAw8CAQEwfTBpMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERp
# Z2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIw
# MjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUAoGkwGAYJKoZI
# hvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjYwMzA4MTc0MzIw
# WjAvBgkqhkiG9w0BCQQxIgQgRWIelu8mWraChvNGfpjOTxlOiVFMOBAg611f8ExY
# k1YwDQYJKoZIhvcNAQEBBQAEggIAeeLVpChFUvAMsHLhmjfK1nphlskJWuKn0Lhi
# /S4N/sQj5+cqYkmlAWG10oiduy8UmpXB4bgg1pRghMGa5TOqJCVEIhghNJBk5tGo
# bwUFEvNgKm2yi6xNJyJDC6i6oDsifoIHck5caCpcJW4mxK85DfW+TRPYCujEBk3I
# LBe+NbqIg13MBK1cK08rtd6FcTCBE3JwNQ2q1WlIwLK8qvPDby6F2biM450xyGQC
# QYImQQU5IZZWzsnHi55quMFDLGl7kIKoLQsBVQLITJT/gaL6J0rlQmbYIznSVVIv
# 1EiqBY1Fs0O6h8ZRmoDy1D0RSX0jMKb2u0WvOyQ/G9AXTsAa60K65I8LquUypV29
# svF863bfmomw8AixxUEch4rufRjYfRQhKZ8wI1hPX05dPh755fP3obsDBTtl6Sm0
# i9geO22ewd0rwsEcLh0G5TvWodaVtCzoS5t/QqOAfwUEWHtGh+rlq+lyAD/0dXJJ
# 7wdNFfO16gzwzI4pQU2YRb/hWoCPrO1aRngHeHHxvpuxJBX1ANBeFU4xnRTiN30U
# 6w/2wZoaSIK/x5YeSjdNg/B/CFpq71Y0vtBSIrGuKDtt2jCWTdoGSIAKmCQZowln
# oq1g2w+wejCfPu7dqHcZmMoYtxfoQTFuMNxnmNGuIg2QOqC22nVBQl1r4oriveVF
# ndxJf90=
# SIG # End signature block
