#############
# FUNCTIONS #
#############

function Exit-IfUpdatesAvailable {
    try {
		Write-Host "Checking for Windows updates..."
		
        # Create a Windows Update session and searcher
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()

        # Search for updates that are not installed
        $results = $searcher.Search("IsInstalled=0 and Type='Software'")

        if ($results.Updates.Count -gt 0) {
			$caption = "Windows updates are available. You must install all Windows updates before running this script."
			$message = "Using this script anyways can cause issues. Are you sure you want to continue?"
			$choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
				New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Continue anyways"
				New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Exit"
			)
			$decision = $host.UI.PromptForChoice($caption, $message, $choices, 1) # 1 = default is No
			if ($decision -eq 1) {
				Start-Process "ms-settings:windowsupdate"
				exit
			}
            
        } else {
            Write-Host "No updates found. Continuing..."
        }
    }
    catch {
        Write-Warning "Unable to check for updates. Error: $_"
    }
}

function Get-LatestAMDInstaller {
    $pageUrl = "https://www.amd.com/en/support/download/drivers.html"

    try {
        # Fetch the page content
        $response = Invoke-WebRequest -Uri $pageUrl -UseBasicParsing

        # Use regex to find the latest Adrenalin installer link
        if ($response.RawContent -match 'https://drivers\.amd\.com/drivers/installer/[\d\.]+/whql/amd-software-adrenalin-edition-[\d\.]+-minimalsetup-[\d]+_web\.exe') {
            return $matches[0]
        } else {
            Write-Warning "Could not find a matching AMD installer link."
            return $null
        }
    }
    catch {
        Write-Error "Failed to retrieve AMD driver page. Error: $_"
        return $null
    }
}

function Get-LatestGeForceInstaller {
    # Define the NVIDIA GeForce Experience download page
    $pageUrl = "https://www.nvidia.com/en-us/geforce/geforce-experience/download/"

    try {
        # Fetch the page content
        $response = Invoke-WebRequest -Uri $pageUrl

        # Extract the installer URL using regex
        if ($response.RawContent -match 'https://us\.download\.nvidia\.com/nvapp/client/[\d\.]+/NVIDIA_app_v[\d\.]+\.exe') {
            return $matches[0]
        }
        else {
            Write-Warning "Installer URL not found in page content."
            return $null
        }
    }
    catch {
        Write-Error "Failed to fetch or parse NVIDIA download page. Error: $_"
        return $null
    }
}

function Install-GPU-Driver {
    param (
        [string]$label,
        [scriptblock]$getUrlFunc
    )

    Write-Host "`nFetching latest $label installer..."
    $installerUrl = & $getUrlFunc
    if ($installerUrl) {
        $filename = Split-Path $installerUrl -Leaf
        $fullPath = Join-Path $tempPath $filename

        Write-Host "Downloading $label installer..."
		Start-Process $fullPath -Wait
		if ($label -eq "AMD") {
			Invoke-WebRequest -Uri $installerUrl -OutFile $fullPath -Headers @{ Referer = "https://www.amd.com" }
		} else {
			Invoke-WebRequest -Uri $installerUrl -OutFile $fullPath -Headers @{ Referer = "https://www.nvidia.com" }
		}

        Write-Host "Running $label installer..."
		if ($label -eq "AMD") {
			Start-Process $fullPath -ArgumentList "-INSTALL" -Wait
		} else {
			Start-Process $fullPath -ArgumentList “/s” -Wait
		}
    } else {
        Write-Warning "$label installer URL not found."
    }
}

function Install-AltGrWEurKeyboard {
    $installerUrl = "https://altgr-weur.eu/weur.exe"
    $filename = Split-Path $installerUrl -Leaf
    $fullPath = Join-Path $tempPath $filename

    try {
        Write-Host "Downloading AltGr-WEur installer..."
        Invoke-WebRequest -Uri $installerUrl -OutFile $fullPath -Headers @{ Referer = "https://altgr-weur.eu" }

        Write-Host "Running installer..."
        Start-Process -FilePath $fullPath -Wait

        Write-Host "Installation complete."
    }
    catch {
        Write-Error "Failed to install AltGr-WEur layout. Error: $_"
    }
}


#########
# SETUP #
#########

# INITIALIZATIONS
$tempPath = [System.IO.Path]::GetTempPath()  # Get temp folder path

# CHECK FOR WINDOWS UPDATES
Exit-IfUpdatesAvailable

# WINDOWS ACTIVATION
$caption = "Windows Activation"
$message = "Do you need to activate Windows?"
$choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
    New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Activate Windows"
    New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Do nothing"
)
$decision = $host.UI.PromptForChoice($caption, $message, $choices, 1) # 1 = default is No
if ($decision -eq 0) {
    Invoke-RestMethod https://get.activated.win | Invoke-Expression
}

# WINDOWS SUBSYSTEM FOR LINUX
$caption = "Windows Subsystem for Linux (WSL)"
$message = "Do you need to install WSL (Ubuntu)?"
$choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
    New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Install WSL"
    New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Do nothing"
)
$decision = $host.UI.PromptForChoice($caption, $message, $choices, 1) # 1 = default is No
if ($decision -eq 0) {
    wsl --install
}

# ALTGR-WEUR KEYBOARD LAYOUT
$caption = "altgr-weur"
$message = "Do you need to install the altgr-weur keyboard layout?"
$choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
    New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Install WSL"
    New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Do nothing"
)
$altgrWeurDecision = $host.UI.PromptForChoice($caption, $message, $choices, 1) # 1 = default is No
# Installed during runtime

# GRAPHICS DRIVERS
$caption = "Graphics Driver Installation"
$message = "Which graphics driver would you like to install?"
$choices = [System.Management.Automation.Host.ChoiceDescription[]]@(
    New-Object System.Management.Automation.Host.ChoiceDescription "&AMD", "Install AMD graphics driver"
    New-Object System.Management.Automation.Host.ChoiceDescription "&NVIDIA", "Install NVIDIA graphics driver"
    New-Object System.Management.Automation.Host.ChoiceDescription "&Skip", "Skip driver installation"
)
$gpuDriverSelection = $host.UI.PromptForChoice($caption, $message, $choices, 2)  # Default to None

# WINGET
# Define your list of programs by ID (you can use the app name too, but IDs are more reliable)
$programs = @(
    @{ Name = "--- Browsers ---"; ID = "" },
    @{ Name = "Google Chrome"; ID = "Google.Chrome" },
    @{ Name = "Mozilla Firefox"; ID = "Mozilla.Firefox" },
	
    @{ Name = "--- Compression ---"; ID = "" },
    @{ Name = "7-Zip"; ID = "7zip.7zip" },
    @{ Name = "NanaZip"; ID = "M2Team.NanaZip" },
    @{ Name = "WinRAR"; ID = "RARLab.WinRAR" },
	
    @{ Name = "--- Developer Tools ---"; ID = "" },
    @{ Name = "AutoHotkey"; ID = "AutoHotkey.AutoHotkey" },
    @{ Name = "Git"; ID = "Git.Git" },
    @{ Name = "PyCharm Community Edition"; ID = "JetBrains.PyCharm.Community" },
    @{ Name = "PyCharm Professional Edition"; ID = "JetBrains.PyCharm.Professional" },
    @{ Name = "Notepad++"; ID = "Notepad++.Notepad++" },
    @{ Name = "Visual Studio Code"; ID = "Microsoft.VisualStudioCode" },
    @{ Name = "WinSCP"; ID = "WinSCP.WinSCP" },
	
    @{ Name = "--- Documents ---"; ID = "" },
    @{ Name = "LibreOffice"; ID = "TheDocumentFoundation.LibreOffice" },
    @{ Name = "Obsidian"; ID = "Obsidian.Obsidian" },
    @{ Name = "OnlyOffice"; ID = "ONLYOFFICE.DesktopEditors" },
	
    @{ Name = "--- Imaging ---"; ID = "" },
    @{ Name = "Blender"; ID = "BlenderFoundation.Blender" },
    @{ Name = "paint.net"; ID = "dotPDNLLC.paintdotnet" },
    @{ Name = "ShareX"; ID = "ShareX.ShareX" },
	
    @{ Name = "--- Media ---"; ID = "" },
    @{ Name = "Audacity"; ID = "Audacity.Audacity" },
    @{ Name = "K-Lite Codec Pack Basic"; ID = "CodecGuide.K-LiteCodecPack.Basic" },
    @{ Name = "MPC-BE"; ID = "MPC-BE.MPC-BE" },
    @{ Name = "MPC-HC"; ID = "clsid2.mpc-hc" },
    @{ Name = "OBS Studio"; ID = "OBSProject.OBSStudio" },
    @{ Name = "Spotify"; ID = "Spotify.Spotify" },
    @{ Name = "Steam"; ID = "Valve.Steam" },
    @{ Name = "VLC Media Player"; ID = "VideoLAN.VLC" },
	
    @{ Name = "--- Messaging ---"; ID = "" },
    @{ Name = "Discord"; ID = "Discord.Discord" },
    @{ Name = "Mozilla Thunderbird"; ID = "Mozilla.Thunderbird" },
    @{ Name = "Zoom"; ID = "Zoom.Zoom" },

    @{ Name = "--- Online Storage ---"; ID = "" },
    @{ Name = "Dropbox"; ID = "Dropbox.Dropbox" },
    @{ Name = "Google Drive"; ID = "Google.Drive" },
    @{ Name = "Microsoft OneDrive"; ID = "Microsoft.OneDrive" },
	
    @{ Name = "--- Other ---"; ID = "" },
    @{ Name = "Open-Shell"; ID = "Open-Shell.Open-Shell-Menu" },
	
    @{ Name = "--- Utilities ---"; ID = "" },
    @{ Name = "AMD Encoder for OBS Studio"; ID = "OBSProject.obs-amd-encoder" },
    @{ Name = "WireGuard"; ID = "WireGuard.WireGuard" },
    @{ Name = "PowerToys (Preview)"; ID = "Microsoft.PowerToys" },
    @{ Name = "TreeSize Free"; ID = "JAMSoftware.TreeSize.Free" }
)
# Installed during runtime

# Show numbered list to the user
Write-Host "`nSelect programs to install (comma-separated indices):`n"
for ($i = 0; $i -lt $programs.Count; $i++) {
    Write-Host "$($i+1)) $($programs[$i].Name)"
}

# Get user input
$input = Read-Host "`nEnter selections (default none)"
$wingetSelections = $input -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }

###########
# RUNTIME #
###########
# Anything that can be run later (i.e. does not need immediate user input) can be run here.

# AltGr-WEur Keyboard
if ($altgrWeurDecision -eq 0) {
	Write-Host "Installing AltGr-WEur Keyboard..."
    Install-AltGrWEurKeyboard
	Write-Host "Done!`n"
}

# GPU DRIVER Installation
switch ($gpuDriverSelection) {
	Write-Host "Installing GPU driver..."
    0 { Install-GPU-Driver -label "AMD" -getUrlFunc { Get-LatestAMDInstaller } }
    1 { Install-GPU-Driver -label "NVIDIA" -getUrlFunc { Get-LatestGeForceInstaller } }
    2 { Write-Host "`GPU driver installation skipped." }
	Write-Host "Done!`n"
}

# WINGET PROGRAM INSTALLATIONS
# Begin installations
if ($wingetSelections.Count -gt 0) {
	
	# Install WINGET
	echo "Grabbing latest winget..."
	$releaseData = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
	$msixUrl = $releaseData.assets |
		Where-Object { $_.browser_download_url -like "*.msixbundle" } |
		Select-Object -ExpandProperty browser_download_url
	$filename = Split-Path $msixUrl -Leaf
	$fullPath = Join-Path $tempPath $filename
	Invoke-RestMethod -Uri $msixUrl -OutFile $fullPath
	Add-AppxPackage -Path $fullPath
	Remove-Item -Path $fullPath
	
	# Install selected programs
	foreach ($index in $wingetSelections) {
		$i = [int]$index - 1
		if ($i -ge 0 -and $i -lt $programs.Count) {
			$pkgId = $programs[$i].ID
			$name = $programs[$i].Name
			Write-Host "`nInstalling $name..."
			winget install --id $pkgId --silent --accept-source-agreements --accept-package-agreements
		}
		else {
			Write-Host "`nInvalid selection: $index"
		}
	}

	Write-Host "`nAll selected installations are complete."
		
} else {
	Write-Host "`nNo winget programs selected."
}

# Program exit
Write-Host "`n`nAll processes complete!"
Write-Host "Press any key to continue..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null