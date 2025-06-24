# PowerShell script to download YouTube channel with manual numbering control
# Requires yt-dlp to be installed and available in PATH

param(
    [string]$ChannelUrl = "https://www.youtube.com/@pixelpoint-io/videos",
    [string]$OutputDir = ".\downloads",
    [int]$StartNumber = 1,
    [string]$Resolution = "720"
)

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "YouTube Channel Downloader (Manual Control)" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan

# Check if yt-dlp is available
try {
    $ytdlpVersion = & yt-dlp --version
    Write-Host "Found yt-dlp version: $ytdlpVersion" -ForegroundColor Green
} catch {
    Write-Host "Error: yt-dlp not found. Please install yt-dlp and ensure it's in your PATH." -ForegroundColor Red
    exit 1
}

# Create downloads directory if it doesn't exist
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir
    Write-Host "Created downloads directory: $OutputDir" -ForegroundColor Yellow
}

# Get list of video URLs from the channel
Write-Host "Getting video list from channel..." -ForegroundColor Yellow
try {
    $videoUrls = & yt-dlp --flat-playlist --print "%(url)s" $ChannelUrl
    $videoCount = ($videoUrls | Measure-Object).Count
    Write-Host "Found $videoCount videos in channel" -ForegroundColor Green
} catch {
    Write-Host "Error: Could not get video list from channel" -ForegroundColor Red
    exit 1
}

# Smart restart: Find the next available number
$videoNumber = $StartNumber
if (Test-Path $OutputDir) {
    $existingFiles = Get-ChildItem -Path $OutputDir -Filter "??-*" | Where-Object { $_.Name -match "^\d{2}-" }
    if ($existingFiles.Count -gt 0) {
        $highestNumber = ($existingFiles | ForEach-Object { 
            if ($_.Name -match "^(\d{2})-") { [int]$matches[1] }
        } | Measure-Object -Maximum).Maximum
        
        if ($highestNumber -ge $StartNumber) {
            $videoNumber = $highestNumber + 1
            Write-Host "Found existing downloads up to $($highestNumber.ToString('D2'))-" -ForegroundColor Yellow
        }
    }
}

# Download each video individually
$currentVideo = 0
$successCount = 0
$failCount = 0
$skippedCount = 0

foreach ($url in $videoUrls) {
    $currentVideo++
    $paddedNumber = $videoNumber.ToString("D2")
    
    # Check if file with this number already exists
    $existingFile = Get-ChildItem -Path $OutputDir -Filter "${paddedNumber}-*" -ErrorAction SilentlyContinue
    if ($existingFile) {
        Write-Host "Skipping ${paddedNumber}- (already exists: $($existingFile.Name))" -ForegroundColor Yellow
        $skippedCount++
        $videoNumber++
        continue
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "Downloading video $currentVideo of $videoCount (${paddedNumber}-)" -ForegroundColor Cyan
    Write-Host "URL: $url" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    try {
        & yt-dlp `
            --output "$OutputDir/${paddedNumber}- %(title)s.%(ext)s" `
            --format "best[height<=${Resolution}]" `
            --concurrent-fragments 16 `
            --progress `
            --no-warnings `
            --continue `
            --no-overwrites `
            $url
        
        Write-Host "Successfully downloaded ${paddedNumber}- ($currentVideo/$videoCount)" -ForegroundColor Green
        $successCount++
        $videoNumber++
    } catch {
        Write-Host "Failed to download ${paddedNumber}- : $url" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
        $videoNumber++
    }
}

# Summary
Write-Host "`n" -NoNewline
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "Channel download completed!" -ForegroundColor Green
Write-Host "Total videos: $videoCount" -ForegroundColor Green
Write-Host "Successful downloads: $successCount" -ForegroundColor Green
Write-Host "Skipped (already exist): $skippedCount" -ForegroundColor Yellow
Write-Host "Failed downloads: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host "Downloads saved to: $OutputDir" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green