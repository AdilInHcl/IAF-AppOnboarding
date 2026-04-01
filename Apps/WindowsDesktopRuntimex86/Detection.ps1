$SoftwareName = "Microsoft Windows Desktop Runtime" 
$IAFVersion1 = "###VERSION###"
$RegistryPaths = @(
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)


foreach ($Path in $RegistryPaths) {
    $InstalledSoftwares = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -like "$SoftwareName*(x86)" -and $_.SystemComponent -ne "1"
    }   
}


If($null -eq $InstalledSoftwares){
    write-output "no version installed , Proceeding with installation"
    Exit 1
}

If($InstalledSoftwares.Count -gt 1){

    foreach ($app in $InstalledSoftwares){
        If ([version]$app.DisplayVersion -ge [version]$IAFVersion1){}
        else{            
            $msg1 = "version found in device - " + $app.DisplayVersion
            write-output "$($msg1) , Proceeding with installation"
            Exit 1
           }
    }
}else{
    If (([version]$InstalledSoftwares.DisplayVersion -ge [version]$IAFVersion1)){
        write-output "Installed"
        Exit 0
    }
    else{            
            $msg2 = "version found in device - " + $InstalledSoftwares.DisplayVersion
            write-output "$($msg2), Proceeding with installation"
            Exit 1
       }
}

