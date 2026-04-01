KEEP THE PACKAGE SOURCES AS CLEAN AS POSSIBLE.

Both MSI and MST should always be named: AcroPro
MSP file name should start with: AcrobatDCUpd*
Otherwise if that will not be possible to achieve in long run - changes into the install script will have to be applied.
Current logic is a middleground between being safe and stable.
But it might turn out that it is not flexible\dynamic enough.

Avoid using any external vbs,bat,cmd,ps1 files.
All additional actions should be included directly in PSADT installation script - rewritten using PSADT built in functions.

All registry settings should be merged and included in:
	HKLM.reg
	HKCU.reg
	HKLM_Uninstall.reg

Depending on their destination.
They will be automatically applied by PSADT Installation\Uninstallation script.

Installation script is created in a way to first try to apply the patch only.
In case if after patch installation application will not be detected or its version will be lower than expected - full reinstallation will be triggered.