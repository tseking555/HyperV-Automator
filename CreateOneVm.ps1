$baseVMpath = "F:\Hyper-V"
$parentDisk = "F:\HyperScripts\noble-server-cloudimg-amd64.vhdx"
$sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHZYwe7mwE3fYmQ8mgCgqbZlY18PrkhtdKJRw1j+BMYr inboc@tech-ubuntu-xj"
$vmSwitch = "InternalSwitch"
$vmName = "ubuntu01"
$vmPath = "$baseVMpath\$vmName"
New-Item -ItemType Directory -Path "$vmPath\Virtual Hard Disks" -Force | Out-Null
New-VHD -Path "$vmPath\Virtual Hard Disks\$vmName.vhdx" -ParentPath $parentDisk -Differencing
Resize-VHD -Path "$vmPath\Virtual Hard Disks\$vmName.vhdx" -SizeBytes 40GB
New-VM -Name $vmName -MemoryStartupBytes 4GB -BootDevice VHD -VHDPath "$vmPath\Virtual Hard Disks\$vmName.vhdx" -Path $baseVMpath -Generation 2 -SwitchName $vmSwitch
Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false
Set-VMProcessor -VMName $vmName -Count 2
New-Item -ItemType Directory -Path "$vmPath\nocloud" -Force | Out-Null

$metadata = @"
instance-id: uuid-$([GUID]::NewGuid())
local-hostname: $vmName
"@
$metadata | Out-File -FilePath "$vmPath\nocloud\meta-data" -Encoding ASCII -Force

$networkConfig = @"
version: 2
ethernets:
  eth0:
    dhcp4: false
    dhcp6: false
    addresses: [192.168.137.2/24]
    nameservers:
      addresses: [192.168.137.254]
      search: [.]
    routes:
      - to: 0.0.0.0/0
        via: 192.168.137.254
"@
$networkConfig | Out-File -FilePath "$vmPath\nocloud\network-config" -Encoding ASCII -Force

$userdata = @"
#cloud-config
timezone: Asia/Shanghai
users:
  - name: king
    gecos: king
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    lock_passwd: false
    plain_text_passwd: "123456"
    ssh_authorized_keys:
      - $sshPubKey
ssh_pwauth: true
disable_root: true
"@
$userdata | Out-File -FilePath "$vmPath\nocloud\user-data" -Encoding ASCII -Force

oscdimg.exe "$vmPath\nocloud" "$vmPath\metadata.iso" -j2 -lcidata
Set-VMFirmware -VMName $vmName -EnableSecureBoot Off
Set-VM -VMName $vmName -AutomaticStopAction ShutDown -AutomaticStartAction StartIfRunning -AutomaticStartDelay (Get-Random -Minimum 100 -Maximum 800)
Get-VM -VMName $vmName | Enable-VMIntegrationService -Name *
Add-VMDvdDrive -VMName $vmName
Set-VMDvdDrive -VMName $vmName -Path "$vmPath\metadata.iso"
Set-VMFirmware -VMName $vmName -FirstBootDevice (Get-VMHardDiskDrive -VMName $vmName)
Start-VM -VMName $vmName