# PowerShell script to download YouTube playlist with yt-dlp defaults
# Requires yt-dlp to be installed and available in PATH

param(
    [string]$BaseOutputDir = ".\playlists",
    [int]$StartNumber = 1
)

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "YouTube Playlist Downloader" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan

# Check if yt-dlp is available
try {
    $ytdlpVersion = & yt-dlp --version
    Write-Host "Found yt-dlp version: $ytdlpVersion" -ForegroundColor Green
} catch {
    Write-Host "Error: yt-dlp not found. Please install yt-dlp and ensure it's in your PATH." -ForegroundColor Red
    Write-Host "Install with: pip install yt-dlp" -ForegroundColor Yellow
    exit 1
}

# Always prompt for playlist URL
Write-Host "`nPlease enter the YouTube playlist URL:" -ForegroundColor Yellow
Write-Host "Example: https://www.youtube.com/playlist?list=PLlNdnoKwDZdwwEWvKXdR9qwDSlnkGtOjq" -ForegroundColor Gray
Write-Host "URL: " -NoNewline -ForegroundColor White
$PlaylistUrl = Read-Host

# Validate URL input
if ([string]::IsNullOrWhiteSpace($PlaylistUrl)) {
    Write-Host "Error: No playlist URL provided." -ForegroundColor Red
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Basic URL validation
if ($PlaylistUrl -notmatch "playlist\?list=" -and $PlaylistUrl -notmatch "youtube\.com" -and $PlaylistUrl -notmatch "youtu\.be") {
    Write-Host "Warning: This doesn't look like a YouTube playlist URL." -ForegroundColor Yellow
    Write-Host "Continuing anyway..." -ForegroundColor Yellow
}

Write-Host "`nValidating playlist URL..." -ForegroundColor Yellow

# Get playlist information
try {
    Write-Host "Getting playlist information..." -ForegroundColor Yellow
    $playlistInfo = & yt-dlp --flat-playlist --print "%(playlist_title)s|%(playlist_count)s" $PlaylistUrl | Select-Object -First 1
    
    if ([string]::IsNullOrWhiteSpace($playlistInfo)) {
        throw "Could not get playlist information"
    }
    
    $playlistTitle, $videoCount = $playlistInfo -split '\|'
    
    # Clean playlist title for folder name (remove invalid characters)
    $cleanTitle = $playlistTitle -replace '[\\/:*?"<>|]', '_'
    $cleanTitle = $cleanTitle.Trim()
    
    Write-Host "`nPlaylist Information:" -ForegroundColor Green
    Write-Host "  Title: $playlistTitle" -ForegroundColor White
    Write-Host "  Videos: $videoCount" -ForegroundColor White
    Write-Host "  Folder: $cleanTitle" -ForegroundColor White
    
} catch {
    Write-Host "Error: Could not get playlist information." -ForegroundColor Red
    Write-Host "Please check that:" -ForegroundColor Yellow
    Write-Host "  - The URL is correct" -ForegroundColor Yellow
    Write-Host "  - The playlist is public" -ForegroundColor Yellow
    Write-Host "  - You have internet connection" -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Create base directory if it doesn't exist
if (!(Test-Path $BaseOutputDir)) {
    New-Item -ItemType Directory -Path $BaseOutputDir | Out-Null
    Write-Host "Created base directory: $BaseOutputDir" -ForegroundColor Yellow
}

# Create playlist-specific directory
$PlaylistDir = Join-Path $BaseOutputDir $cleanTitle
if (!(Test-Path $PlaylistDir)) {
    New-Item -ItemType Directory -Path $PlaylistDir | Out-Null
    Write-Host "Created playlist directory: $PlaylistDir" -ForegroundColor Yellow
} else {
    Write-Host "Using existing playlist directory: $PlaylistDir" -ForegroundColor Yellow
}

# Smart restart: Find the next available number
$videoNumber = $StartNumber
if (Test-Path $PlaylistDir) {
    $existingFiles = Get-ChildItem -Path $PlaylistDir -Filter "??-*" | Where-Object { $_.Name -match "^\d{2}-" }
    if ($existingFiles.Count -gt 0) {
        $highestNumber = ($existingFiles | ForEach-Object { 
            if ($_.Name -match "^(\d{2})-") { [int]$matches[1] }
        } | Measure-Object -Maximum).Maximum
        
        if ($highestNumber -ge $StartNumber) {
            $videoNumber = $highestNumber + 1
            Write-Host "Found existing downloads up to $($highestNumber.ToString('D2'))-" -ForegroundColor Yellow
            Write-Host "Will start from $($videoNumber.ToString('D2'))-" -ForegroundColor Yellow
        }
    }
}

# Confirm before starting download
Write-Host "`n" -NoNewline
Write-Host "Ready to download:" -ForegroundColor Cyan
Write-Host "  Playlist: $playlistTitle" -ForegroundColor White
Write-Host "  Videos: $videoCount" -ForegroundColor White
Write-Host "  Quality: yt-dlp defaults (best available)" -ForegroundColor White
Write-Host "  Output: $PlaylistDir" -ForegroundColor White
Write-Host "  Starting from: $($videoNumber.ToString('D2'))-" -ForegroundColor White

Write-Host "`nPress Enter to start download or Ctrl+C to cancel..." -ForegroundColor Yellow
Read-Host

# Get list of video URLs from the playlist
Write-Host "Getting video list from playlist..." -ForegroundColor Yellow
try {
    $videoUrls = & yt-dlp --flat-playlist --print "%(url)s" $PlaylistUrl
    $actualVideoCount = ($videoUrls | Measure-Object).Count
    Write-Host "Retrieved $actualVideoCount video URLs" -ForegroundColor Green
} catch {
    Write-Host "Error: Could not get video list from playlist" -ForegroundColor Red
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Download each video individually with progress tracking
$currentVideo = 0
$successCount = 0
$failCount = 0
$skippedCount = 0
$startTime = Get-Date

Write-Host "`nStarting downloads..." -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green

foreach ($url in $videoUrls) {
    $currentVideo++
    $paddedNumber = $videoNumber.ToString("D2")
    
    # Check if file with this number already exists
    $existingFile = Get-ChildItem -Path $PlaylistDir -Filter "${paddedNumber}-*" -ErrorAction SilentlyContinue
    if ($existingFile) {
        Write-Host "Skipping ${paddedNumber}- (already exists: $($existingFile.Name))" -ForegroundColor Yellow
        $skippedCount++
        $videoNumber++
        continue
    }
    
    $elapsedTime = (Get-Date) - $startTime
    $estimatedTotalTime = if ($successCount -gt 0) { 
        $elapsedTime.TotalMinutes * $actualVideoCount / $successCount 
    } else { 
        0 
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "Downloading video $currentVideo of $actualVideoCount (${paddedNumber}-)" -ForegroundColor Cyan
    Write-Host "Elapsed: $([math]::Round($elapsedTime.TotalMinutes, 1)) min" -ForegroundColor Gray
    if ($estimatedTotalTime -gt 0) {
        Write-Host "Estimated total: $([math]::Round($estimatedTotalTime, 1)) min" -ForegroundColor Gray
    }
    Write-Host "URL: $url" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    try {
        # Minimal yt-dlp command - let it use its defaults
        & yt-dlp `
            --output "$PlaylistDir/${paddedNumber}- %(title)s.%(ext)s" `
            $url
        
        Write-Host "Successfully downloaded ${paddedNumber}- ($currentVideo/$actualVideoCount)" -ForegroundColor Green
        $successCount++
        $videoNumber++
    } catch {
        Write-Host "Failed to download ${paddedNumber}- : $url" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        
        # Log failed URL
        $failedUrl = "# Failed on $(Get-Date) - ${paddedNumber}-: $url"
        Add-Content -Path (Join-Path $PlaylistDir "failed_downloads.txt") -Value $failedUrl
        
        $failCount++
        $videoNumber++
    }
}

# Final summary
$totalTime = (Get-Date) - $startTime
Write-Host "`n" -NoNewline
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "DOWNLOAD COMPLETED!" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "Playlist: $playlistTitle" -ForegroundColor White
Write-Host "Quality: yt-dlp defaults" -ForegroundColor White
Write-Host "Total videos in playlist: $actualVideoCount" -ForegroundColor White
Write-Host "Successful downloads: $successCount" -ForegroundColor Green
Write-Host "Skipped (already exist): $skippedCount" -ForegroundColor Yellow
Write-Host "Failed downloads: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host "Total time: $([math]::Round($totalTime.TotalMinutes, 1)) minutes" -ForegroundColor White
Write-Host "Average per video: $([math]::Round($totalTime.TotalMinutes / [math]::Max($successCount, 1), 1)) minutes" -ForegroundColor White
Write-Host "Downloads saved to: $PlaylistDir" -ForegroundColor White

if ($failCount -gt 0) {
    Write-Host "Failed URLs logged to: $(Join-Path $PlaylistDir 'failed_downloads.txt')" -ForegroundColor Yellow
}

Write-Host "=" * 80 -ForegroundColor Green

# Show downloaded files summary
if (Test-Path $PlaylistDir) {
    $downloadedFiles = Get-ChildItem -Path $PlaylistDir -Filter "*.*" | Where-Object { $_.Extension -match '\.(mp4|mkv|webm|avi)$' } | Sort-Object Name
    if ($downloadedFiles.Count -gt 0) {
        Write-Host "`nDownloaded files ($($downloadedFiles.Count)):" -ForegroundColor Yellow
        $downloadedFiles | Select-Object -First 5 | ForEach-Object { 
            Write-Host "  $($_.Name)" -ForegroundColor White 
        }
        if ($downloadedFiles.Count -gt 5) {
            Write-Host "  ... and $($downloadedFiles.Count - 5) more files" -ForegroundColor Gray
        }
    }
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")