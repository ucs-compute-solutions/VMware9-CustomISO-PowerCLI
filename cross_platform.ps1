# Check the OS type
$os = $env:OS

# Function to select file using Zenity for macOS/Linux
function Select-File-Zenity {
    param ([string]$title)
    $file = zenity --file-selection --title="$title"
    return $file
}

# Function to get ZIP files in a folder
function Get-ZipFiles {
    param ([string]$folderPath)
    Get-ChildItem -Path $folderPath -Filter "*.zip" -Recurse -File
}

# Function for Windows GUI
function Create-WindowsForm {
    Add-Type -AssemblyName System.Windows.Forms

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'User Input for ESXi and Driver ZIP Files'
    $form.Size = New-Object System.Drawing.Size(500, 200)

    $esxiLabel = New-Object System.Windows.Forms.Label
    $esxiLabel.Text = 'ESXi ZIP File:'
    $esxiLabel.Location = New-Object System.Drawing.Point(10, 20)
    $form.Controls.Add($esxiLabel)

    $esxiTextBox = New-Object System.Windows.Forms.TextBox
    $esxiTextBox.Location = New-Object System.Drawing.Point(120, 20)
    $esxiTextBox.Size = New-Object System.Drawing.Size(200, 20)
    $form.Controls.Add($esxiTextBox)

    $browseEsxiButton = New-Object System.Windows.Forms.Button
    $browseEsxiButton.Text = 'Browse'
    $browseEsxiButton.Location = New-Object System.Drawing.Point(330, 18)
    $form.Controls.Add($browseEsxiButton)

    $driverLabel = New-Object System.Windows.Forms.Label
    $driverLabel.Text = 'Driver ZIP File:'
    $driverLabel.Location = New-Object System.Drawing.Point(10, 60)
    $form.Controls.Add($driverLabel)

    $driverTextBox = New-Object System.Windows.Forms.TextBox
    $driverTextBox.Location = New-Object System.Drawing.Point(120, 60)
    $driverTextBox.Size = New-Object System.Drawing.Size(200, 20)
    $form.Controls.Add($driverTextBox)

    $browseDriverButton = New-Object System.Windows.Forms.Button
    $browseDriverButton.Text = 'Browse'
    $browseDriverButton.Location = New-Object System.Drawing.Point(330, 58)
    $form.Controls.Add($browseDriverButton)

    $submitButton = New-Object System.Windows.Forms.Button
    $submitButton.Text = 'Submit'
    $submitButton.Location = New-Object System.Drawing.Point(150, 100)
    $form.Controls.Add($submitButton)

    $browseEsxiButton.Add_Click({
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Filter = "ZIP Files|*.zip"
        $fileDialog.Title = "Select the ESXi ZIP File"
        if ($fileDialog.ShowDialog() -eq "OK") {
            $esxiTextBox.Text = $fileDialog.FileName
        }
    })

    $browseDriverButton.Add_Click({
        $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $fileDialog.Filter = "ZIP Files|*.zip"
        $fileDialog.Title = "Select the Driver ZIP File"
        if ($fileDialog.ShowDialog() -eq "OK") {
            $driverTextBox.Text = $fileDialog.FileName
        }
    })

    $submitButton.Add_Click({
        $esxiZipPath = $esxiTextBox.Text
        $driverZipPath = $driverTextBox.Text

        if (-Not (Test-Path $esxiZipPath)) {
            [System.Windows.Forms.MessageBox]::Show("The ESXi ZIP file does not exist.", "Error")
            return
        }
        if (-Not (Test-Path $driverZipPath)) {
            [System.Windows.Forms.MessageBox]::Show("The Driver ZIP file does not exist.", "Error")
            return
        }

        $form.Close()
        Process-Files -esxiZipPath $esxiZipPath -driverZipPath $driverZipPath
    })

    $form.ShowDialog()
}

# Function to read packages from nested metadata.zip inside driver ZIPs
function Get-PackagesFromDriverZip {
    param (
        [string]$zipFilePath,
        [string[]]$softwarePackages
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $foundPackages = @()

    try {
        # Open outer ZIP
        $zip = [System.IO.Compression.ZipFile]::OpenRead($zipFilePath)

        # Look for metadata.zip entry
        $metadataEntry = $zip.Entries | Where-Object { $_.FullName -ieq 'metadata.zip' }

        if (-not $metadataEntry) {
            Write-Host "No metadata.zip found inside $zipFilePath"
            $zip.Dispose()
            return $foundPackages
        }

        # Extract metadata.zip to memory stream
        $metadataStream = New-Object System.IO.MemoryStream
        $metadataEntry.Open().CopyTo($metadataStream)
        $metadataStream.Position = 0

        # Open nested metadata.zip
        $metadataZip = [System.IO.Compression.ZipArchive]::new($metadataStream, [System.IO.Compression.ZipArchiveMode]::Read)

        # Look for files inside vibs folder in metadata.zip
        $vibFiles = $metadataZip.Entries | Where-Object { $_.FullName -like 'vibs/*' -and -not $_.FullName.EndsWith('/') }

        foreach ($vibFile in $vibFiles) {
            $vibFileName = [System.IO.Path]::GetFileName($vibFile.FullName)

            foreach ($pkg in $softwarePackages) {
                if ($vibFileName -like "*$pkg*") {
                    if (-not $foundPackages.Contains($pkg)) {
                        $foundPackages += $pkg
                    }
                }
            }
        }

        $metadataZip.Dispose()
        $metadataStream.Dispose()
        $zip.Dispose()
    }
    catch {
        Write-Warning "Failed to process ${zipFilePath}: $_"
    }

    return $foundPackages
}

# Function to get ZIP files in a folder
function Get-ZipFiles {
    param ([string]$folderPath)
    Get-ChildItem -Path $folderPath -Filter "*.zip" -Recurse -File
}

# Function to process ESXi & Driver ZIP files
function Process-Files {
    param (
        [string]$esxiZipPath,
        [string]$driverZipPath
    )

    Write-Host "########Adding ESXi ZIP############: $esxiZipPath"
    Add-EsxSoftwareDepot $esxiZipPath
    Write-Host "Add-EsxSoftwareDepot $esxiZipPath"

    # Create a new temporary folder for extraction
    $tempExtractPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempExtractPath | Out-Null

    Write-Host "Extracting driver ZIP to temporary folder: $tempExtractPath"
    Expand-Archive -Path $driverZipPath -DestinationPath $tempExtractPath -Force

    # Get the single folder extracted inside the temp folder
    $subFolders = Get-ChildItem -Path $tempExtractPath -Directory

    if ($subFolders.Count -ne 1) {
        Write-Host "Expected exactly one folder after extraction, found $($subFolders.Count)."
        return
    }

    $driverFolderPath = $subFolders[0].FullName
    Write-Host "Using extracted folder: $driverFolderPath"

    $zipFiles = Get-ZipFiles -folderPath $driverFolderPath
    #Write-Host "****************************************: $zipFiles"

    $softwarePackages = @("nenic", "nfnic", "i40en", "icen", "ixgben", "igbn", "lpfc", "qlnativefc","smartpqi","nenic-ens","iavmd","ucs-tool-esxi","qcnic","qedi")

    # Collect all detected packages from all driver zip files
    $detectedPackages = @()

    foreach ($zipFile in $zipFiles) {
        $zipFilePath = $zipFile.FullName
        Write-Host "Checking inside driver ZIP: $zipFilePath"

        $packagesInZip = Get-PackagesFromDriverZip -zipFilePath $zipFilePath -softwarePackages $softwarePackages

        if ($packagesInZip.Count -gt 0) {
            Write-Host "Detected packages in ${zipFilePath}: $($packagesInZip -join ', ')"
            $detectedPackages += $packagesInZip
        }

        Write-Host "Adding Driver ZIP: $zipFilePath"
        Add-EsxSoftwareDepot -DepotUrl $zipFilePath
    }

    # Remove duplicates
    $detectedPackages = $detectedPackages | Select-Object -Unique

    if ($detectedPackages.Count -eq 0) {
        Write-Host "No matching packages detected in driver ZIP files."
        return
    }

    Write-Host "Filtered software packages to add: $($detectedPackages -join ', ')"

    $standardProfiles = Get-EsxImageProfile | Where-Object { $_.Name -like "*standard*" }
    if ($standardProfiles.Count -eq 0) {
        Write-Host "No standard image profiles found."
        return
    }

    $profile = $standardProfiles[0]
    $currentDateTime = Get-Date -Format "yyyyMMdd-HHmm"
    $customProfileName = "$($profile.Name)-Custom-$currentDateTime"

    if (Get-EsxImageProfile -Name $customProfileName) {
        Write-Host "Custom profile already exists."
        return
    }

    Write-Host "Creating new profile: $customProfileName"
    New-EsxImageProfile -CloneProfile $profile.Name -Name $customProfileName -Vendor Cisco
    $imageProfile = Get-EsxImageProfile -Name $customProfileName

    $installedPackages = $imageProfile.VibList

    foreach ($package in $detectedPackages) {
        if ($installedPackages -notcontains $package) {
            Write-Host "Adding package '$package' to profile '$customProfileName'"
            $imageProfile | Add-EsxSoftwarePackage -SoftwarePackage $package
        } else {
            Write-Host "Package '$package' already exists. Skipping..."
        }
    }

    Write-Host "Setting profile to 'PartnerSupported'"
    Set-EsxImageProfile -AcceptanceLevel PartnerSupported -ImageProfile $customProfileName

    Write-Host "Exporting ISO... $PWD\$customProfileName.iso"
    Export-EsxImageProfile -ImageProfile $customProfileName -FilePath "$PWD\$customProfileName.iso" -ExportToIso -Force -NoSignatureCheck
    Write-Host "Exporting Depot... $PWD\$customProfileName.zip"
    Export-EsxImageProfile -ImageProfile $customProfileName -FilePath "$PWD\$customProfileName.zip"  -ExportToBundle -Force -NoSignatureCheck
}

# Start script based on OS
if ($os -eq "Windows_NT") {
    Write-Host "Running Windows GUI..."
    Create-WindowsForm
} else {
    Write-Host "Running on macOS/Linux..."
    $esxiZipPath = Select-File-Zenity "Select the ESXi ZIP File"
    $driverZipPath = Select-File-Zenity "Select the Driver ZIP File"

    if ($esxiZipPath -and $driverZipPath) {
        Process-Files -esxiZipPath $esxiZipPath -driverZipPath $driverZipPath
    } else {
        Write-Host "File selection cancelled."
    }
}
