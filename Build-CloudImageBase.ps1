# ====================== PATH CONFIG ======================
# Base directory for VM images
$pathImage = "F:\Hyper-V\"
# Ubuntu Noble cloud image URL
$Imageurl = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
# Full path to the downloaded cloud image
$sourceImage = Join-Path $pathImage "noble-server-cloudimg-amd64.img"
# Output path for converted VHDX disk
$outputVHDX = Join-Path $pathImage "noble-server-cloudimg-amd64.vhdx"
# ==========================================================

# Check administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "ERROR: Please run PowerShell as Administrator!"
    exit 1
}

# Create directory if it does not exist
if (-not (Test-Path $pathImage)) {
    New-Item -ItemType Directory -Path $pathImage -Force | Out-Null
}

# Check if the cloud image already exists
if (Test-Path $sourceImage) {
    Write-Host "File exists, skipping download: $sourceImage" -ForegroundColor Green
}
else {
    Write-Host "File not found, starting resumable download..." -ForegroundColor Cyan

    # Force create Bits transfer job (resumable)
    Start-BitsTransfer -Source $Imageurl -Destination $sourceImage -TransferType Download

    # Verify download success
    if (-not (Test-Path $sourceImage)) {
        Write-Error "ERROR: Image download failed!"
        exit 1
    }
    Write-Host "Download completed: $sourceImage" -ForegroundColor Green
}

# Final check for source image
if (-not (Test-Path $sourceImage)) {
    Write-Error "ERROR: Source cloud image not found at: $sourceImage"
    exit 1
}

Write-Host "`n=== Converting cloud image to VHDX ===" -ForegroundColor Cyan

# Convert format: qcow2 -> dynamic VHDX
& .\qemu-img\qemu-img.exe convert -f qcow2 "$sourceImage" -O vhdx -o subformat=dynamic "$outputVHDX"

if (-not (Test-Path $outputVHDX)) {
    Write-Error "ERROR: VHDX conversion failed!"
    exit 1
}

Write-Host "VHDX created: $outputVHDX"

# Disable sparse file (required for Hyper-V!)
Write-Host "`n=== Disabling sparse file attribute ===" -ForegroundColor Cyan
fsutil sparse setflag "$outputVHDX" 0

# Verify sparse file status
$sparseStatus = fsutil sparse queryflag "$outputVHDX"
Write-Host "Sparse file status: $sparseStatus"

Write-Host "`nBase image build completed successfully!" -ForegroundColor Green
Write-Host "Your base disk is ready: $outputVHDX`n"