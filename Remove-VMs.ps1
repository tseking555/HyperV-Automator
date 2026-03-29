# ====================== CONFIG ======================
# Directory for storing virtual machines
$baseVMpath = "F:\Hyper-V"
# List of virtual machines to be deleted
$vmList = @(
     "king-sys-prod-dns-01",
     "king-sys-prod-dns-02",
     "king-sys-prod-chrony",
     "king-sys-prod-nginx",
     "king-sys-prod-postgresql",
     "king-sys-prod-mysql",
     "king-sys-prod-rke2-01",
     "king-sys-prod-rke2-02",
     "king-sys-prod-rke2-03",
    "king-sys-test-lnmp"
)
# ========================================================================

# Check administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ERROR: Run PowerShell as Administrator!"
    exit 1
}

# Loop to delete each virtual machine
foreach ($vmName in $vmList) {
    Write-Host "`n=== Removing VM: $vmName ===" -ForegroundColor Red

    # 1. Stop the virtual machine if it is runningv
    if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
        Stop-VM -Name $vmName -Force -ErrorAction SilentlyContinue
        Write-Host "VM $vmName stopped."
    }

    # 2. Delete the virtual machine
    if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
        Remove-VM -Name $vmName -Force
        Write-Host "VM $vmName deleted from Hyper-V."
    }

    # 3. Delete all files and directories of the virtual machine
    $vmFullPath = Join-Path $baseVMpath $vmName
    if (Test-Path $vmFullPath) {
        Remove-Item -Path $vmFullPath -Recurse -Force
        Write-Host "VM folder $vmFullPath deleted."
    }

    Write-Host "VM $vmName removed completely." -ForegroundColor Green
}

Write-Host "`nAll specified VMs and files have been removed!`n" -ForegroundColor Green