# Scrappers

## 📋 Prerequisites

### Required Software

1. **yt-dlp** (Required: ACTUALLY AVAILABLE IN THIS REPOSITORY)

   - Download from: [https://github.com/yt-dlp/yt-dlp/releases](https://github.com/yt-dlp/yt-dlp/releases)
   - Extract to `C:\yt-dlp`
   - Add `C:\yt-dlp` to your system PATH

2. **FFmpeg** (Recommended)
   - Download from: [https://ffmpeg.org/download.html](https://ffmpeg.org/download.html)
   - Required for video processing and format conversion

### PowerShell Setup

Enable PowerShell to execute local scripts by running this command as Administrator:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

run `scrap.ps1` by: `./scrap.ps1` on terminal

## 📁 Usage

1. **Run the script:**

   ```powershell
   ./scrap.ps1
   ```

2. **Enter playlist URL when prompted:**

   ```
   Example: https://www.youtube.com/playlist?list=PLlNdnoKwDZdwwEWvKXdR9qwDSlnkGtOjq
   ```

3. **The script will:**
   - Create a folder named after the playlist
   - Download videos as `01- Title.mp4`, `02- Title.mp4`, etc.
   - Show download progress for each video
   - Skip already downloaded files on restart
