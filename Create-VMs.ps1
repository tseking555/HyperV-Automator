# ====================== CONFIG ======================
# Virtual machine storage path
$baseVMpath = "F:\Hyper-V"
# VHDX disk file path
$parentDisk = "$baseVMpath\noble-server-cloudimg-amd64.vhdx"
$vmSwitch = "InternalSwitch"
$sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAGylQone9YMJ03ub5BpLtNbTPG9lSUCHY03p7987AGc king-labs"
# Virtual machine list to create
$vmList = @(
#     @{ Name = "king-sys-prod-dns-01"; IP = "192.168.137.1/24"; Cores = "1"; Memory = "1" },
#     @{ Name = "king-sys-prod-dns-02"; IP = "192.168.137.2/24"; Cores = "1"; Memory = "1" },
#     @{ Name = "king-sys-prod-chrony"; IP = "192.168.137.3/24"; Cores = "1"; Memory = "1" },
#     @{ Name = "king-sys-prod-nginx"; IP = "192.168.137.4/24"; Cores = "1"; Memory = "2" },
#     @{ Name = "king-sys-prod-postgresql"; IP = "192.168.137.5/24"; Cores = "2"; Memory = "4" },
#     @{ Name = "king-sys-prod-mysql"; IP = "192.168.137.6/24"; Cores = "2"; Memory = "4" },
#     @{ Name = "king-sys-prod-rke2-01"; IP = "192.168.137.7/24"; Cores = "2"; Memory = "4" },
#     @{ Name = "king-sys-prod-rke2-02"; IP = "192.168.137.8/24"; Cores = "2"; Memory = "4" },
#     @{ Name = "king-sys-prod-rke2-03"; IP = "192.168.137.9/24"; Cores = "2"; Memory = "4" }
    @{ Name = "king-sys-test-lnmp"; IP = "192.168.137.50/24"; Cores = "2"; Memory = "4" }
)
# ======================================================

# Check administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ERROR: Run PowerShell as Administrator!"
    exit 1
}

foreach ($vm in $vmList) {
    $vmName = $vm.Name
    $vmIP = $vm.IP
    $vmCores = $vm.Cores
    $MemoryGB = [int]$vm.Memory
    $MemoryStartupBytes = $MemoryGB * 1GB
    $vmPath = "$baseVMpath\$vmName"
    $vhdPath = "$vmPath\Virtual Hard Disks\$vmName.vhdx"
    $nocloudPath = "$vmPath\nocloud"
    $isoPath = "$vmPath\metadata.iso"

    Write-Host "`n=== Creating VM: $vmName ===" -ForegroundColor Cyan

    # Create required folders
    New-Item -ItemType Directory -Path "$vmPath\Virtual Hard Disks" -Force | Out-Null
    New-Item -ItemType Directory -Path $nocloudPath -Force | Out-Null

    # Create differencing disk
    New-VHD -Path $vhdPath -ParentPath $parentDisk -Differencing | Out-Null
    Resize-VHD -Path $vhdPath -SizeBytes 40GB | Out-Null

    # Create virtual machine
    New-VM -Name $vmName -MemoryStartupBytes $MemoryStartupBytes -BootDevice VHD -VHDPath $vhdPath -Path $baseVMpath -Generation 2 -SwitchName $vmSwitch | Out-Null

    # Configure VM hardware settings
    Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false
    Set-VMProcessor -VMName $vmName -Count $vmCores
    Set-VMFirmware -VMName $vmName -EnableSecureBoot Off

    # Cloud-Init meta-data configuration
    @"
instance-id: uuid-$([GUID]::NewGuid())
local-hostname: $vmName
"@ | Out-File "$nocloudPath\meta-data" -Encoding ASCII -Force

    # Network configuration
    @"
version: 2
ethernets:
  eth0:
    dhcp4: false
    dhcp6: false
    addresses: [$vmIP]
    nameservers:
      addresses: [192.168.137.254]
    routes:
      - to: 0.0.0.0/0
        via: 192.168.137.254
"@ | Out-File "$nocloudPath\network-config" -Encoding ASCII -Force

    # User-data configuration
    @"
#cloud-config
timezone: Asia/Shanghai
users:
  - name: king
    gecos: TseKing
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, sudo
    lock_passwd: false
    plain_text_passwd: "Tse@2020"
    ssh_authorized_keys:
      - $sshPubKey
ssh_pwauth: true
disable_root: true
"@ | Out-File "$nocloudPath\user-data" -Encoding ASCII -Force

    # Create metadata ISO image
    .\oscdimg.exe "$nocloudPath" "$isoPath" -j2 -lcidata | Out-Null

    # Mount ISO and set boot order
    Set-VM -VMName $vmName -AutomaticStopAction ShutDown -AutomaticStartAction StartIfRunning
    Get-VM $vmName | Enable-VMIntegrationService -Name *
    Add-VMDvdDrive -VMName $vmName | Out-Null
    Set-VMDvdDrive -VMName $vmName -Path $isoPath
    Set-VMFirmware -VMName $vmName -FirstBootDevice (Get-VMHardDiskDrive -VMName $vmName)

    # Start the virtual machine
    Start-VM -VMName $vmName

    Write-Host "VM $vmName created and started successfully!" -ForegroundColor Green
}

Write-Host "`nAll VMs deployed successfully!`n" -ForegroundColor Green