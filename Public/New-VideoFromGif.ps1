function New-GifFromVideo {
   param(
       [string]$VideoPath,
       [string]$GifPath,
       [int]$StartTime = 0, # Start time in seconds
       [int]$Duration = 5, # Duration of the gif in seconds
       [int]$Width = 480, # Width of the gif
       [int]$Fps = 10 # Frames per second for higher quality
   )

   if (-Not (Test-Path $VideoPath)) {
       Write-Error "Video file not found: $VideoPath"
       return
   }

   $palette = "$([System.IO.Path]::GetTempPath())palette.png"
   $filters = "fps=$Fps,scale=${Width}:-1:flags=lanczos"

   # Generate palette for high quality
   $ffmpegPaletteCmd = "ffmpeg -y -ss $StartTime -t $Duration -i `"$VideoPath`" -vf `"$filters,palettegen`" -y `"$palette`""
   $ffmpegGifCmd = "ffmpeg -y -ss $StartTime -t $Duration -i `"$VideoPath`" -i `"$palette`" -lavfi `"$filters [x]; [x][1:v] paletteuse`" -y `"$GifPath`""

   try {
       Invoke-Expression $ffmpegPaletteCmd
       Invoke-Expression $ffmpegGifCmd
       Write-Output "High-quality GIF created at: $GifPath"
   }
   catch {
       Write-Error "Failed to create high-quality GIF: $_"
   }
   finally {
       # Cleanup palette image
       Remove-Item $palette -ErrorAction Ignore
   }
}