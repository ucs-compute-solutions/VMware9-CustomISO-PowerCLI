
# 🔧 Custom ESXi ISO and Depot Creation Guide

This PowerShell script is to create a custom ESXi ISO and Depot by injecting async drivers into a standard VMware ESXI image. The script supports both Windows and macOS.

---

### Prerequisite for windows

>Python 3.7.1–3.12 (As per current PowerCLI support, Python 3.12+ is not supported, as VMware PowerCLI doesn't yet support versions beyond 3.12, Support in script will be extended once PowerCLI adds compatibility)

## 📂 Required Files

1. **ESXi Depot ZIP**  
   Download the ESXi base image (depot.zip) from the VMware website.(Required to create a custom ESXi ISO.)
   **Example:** `VMware-ESXi-9.0.0.0.24755229-depot.zip`

2. **Driver ZIP**  
   Download the drivers .zip file from software.cisco.com (for example, Cisco_UCS_Drivers_ESXi.5.4.0b.zip) and from within that file extract the specific drivers .zip file matching the VMware release.  
   **Example:** `Cisco_UCS_Drivers_ESXi_9.0_24755229.zip`(having all the required async drivers for creating custom image.)
---

### Prerequisite for Mac

> ⚠️ PowerShell must be installed via Homebrew.

## Steps to Install PowerShell

>> Install brew if it is not already available in your system using below cli command
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# CLI Command to install powershell

brew install --cask powershell

## 📂 Required Files

1. **ESXi Depot ZIP**  
   Download the ESXi base image (depot.zip) from the VMware website.(Required to create a custom ESXi ISO.)
   **Example:** `VMware-ESXi-9.0.0.0.24755229-depot.zip`

2. **Driver ZIP**  
   Download the drivers .zip file from software.cisco.com (for example, Cisco_UCS_Drivers_ESXi.5.4.0b.zip) and from within that file extract the specific drivers .zip file matching the VMware release.  
   **Example:** `Cisco_UCS_Drivers_ESXi_9.0_24755229.zip`(having all the required async drivers for creating custom image.)
---

## 📦 Modules Installed by the Script

- **VMware PowerCLI**
- **Python modules**:
  - `six`
  - `lxml`
  - `psutil`
  - `pyOpenSSL`

---


## 🪟 Steps for Running script on Windows

### Steps

1. Download the script files.(`package_install.ps1` and  `cross_platform.ps1`)
2. Open **PowerShell as Administrator**.
3. Navigate to the script folder downloaded.
4. Run the below command in powershell to create custom iso:
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; ./package_install.ps1
5. choose **Yes**, when prompted with *"Performing operation?"*, 
6. A graphical form will appear:
   - First, select the **ESXi depot ZIP which was downloaded from VMware website defined in prerequisite**.
   - Then, select the **Driver.zip defined in prerequsite**.

7. The **custom ESXi ISO** will be created in the same directory, named with the original image name and current timestamp.

# Note: If we run the script for the first time it approximetly takes 10 minutes to install all the required packages, but subsiquient creation will take 1-2 minut,

---

## 🍏 Running on macOS

### Steps to Run the Script

1. Open PowerShell with root privileges using below cli command:
   sudo pwsh

2. Execute the script:
   ./package_install.ps1
   
3. A folder picker will appear:
   - First, select the **ESXi depot ZIP which was downloaded from VMware website defined in prerequisite**.
   - Then, select the **Driver.zip defined in prerequsite**.

4. The **custom ESXi ISO** will be created in the same directory, named with the original image name and current timestamp.


## ❗ Troubleshooting

If you encounter permission-related errors during execution, run the following command:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

## NOTE:
VMware PowerCLI does **not officially support pre-release versions** of Python.  
To ensure full compatibility and avoid unexpected issues, please use a stable release of Python.

### ❌ Unsupported:
- Pre-release versions (e.g., alpha, beta, release candidate)
- Python versions not listed in official PowerCLI documentation

## After Running the Script
The script will produce two files: 

1. A Cisco Custom ISO Image that can be used to install or upgrade VMware ESXi hosts to VMware ESXi 9 with Cisco-recommended drivers. Once this host is built, its image can be imported into vCenter 9 vLCM to serve as a required reference image for the cluster. This reference image can be exported to JSON to be used by other clusters within the vCenter.

2. A Depot.zip file that can be imported into vCenter 9 vLCM to produce a required reference image for the cluster. This reference image can be exported to JSON to be used by other clusters within the vCenter.
