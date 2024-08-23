function Invoke-ExtractTranscript {
   param (
       [string]$videoPath,
       [string]$ffmpegPath = "ffmpeg",
       [string]$whisperPath = "whisper",
       [ValidateSet("tiny", "small", "medium", "large", "base")][string]$model = "base",
       [string]$transcriptFolder = "",
       [string]$language = "en"  # Added language parameter with default value 'en'
   )

   # Check if the video file exists
   if (-Not (Test-Path -Path $videoPath)) {
       Write-Error "The specified video file does not exist: $videoPath"
       return
   }

   # Create a folder with the name of the video (without extension) if not manually provided
   $videoName = [System.IO.Path]::GetFileNameWithoutExtension($videoPath)
   
   if (-not $transcriptFolder) {
       $transcriptFolder = Join-Path -Path (Get-Location) -ChildPath "${videoName}"
   }

   if (-Not (Test-Path -Path $transcriptFolder -PathType Container)) {
       try {
           New-Item -ItemType Directory -Path $transcriptFolder -ErrorAction Stop | Out-Null
       }
       catch {
           Write-Error "Failed to create transcript directory: $_"
           return
       }
   }

   # Move the video file to the transcript folder
   $newVideoPath = Join-Path -Path $transcriptFolder -ChildPath (Get-Item $videoPath).Name
   try {
       Move-Item -Path $videoPath -Destination $newVideoPath -Force
   }
   catch {
       Write-Error "Failed to move the video file to the transcript directory: $_"
       return
   }

   # Define the output audio file path
   $audioPath = [System.IO.Path]::ChangeExtension($newVideoPath, ".mp3")

   try {
       # Extract audio from the video file using FFmpeg
       $ffmpegCommand = "-i `"$newVideoPath`" -q:a 0 -map a `"$audioPath`""
       Write-Output "Extracting audio from video..."
       Start-Process -FilePath $ffmpegPath -ArgumentList $ffmpegCommand -Wait -NoNewWindow -ErrorAction Stop

       # Check if the audio file was created
       if (-Not (Test-Path -Path $audioPath)) {
           Write-Error "Failed to extract audio."
           return
       }

       # Run Whisper on the extracted audio file and save output to transcript files
       $whisperCommand = "`"$audioPath`" --model $model --output_dir `"$transcriptFolder`" --language $language --device cuda --output_format vtt"
       Write-Output "Running Whisper on the extracted audio using model '$model' and language '$language'..."
       Start-Process -FilePath $whisperPath -ArgumentList $whisperCommand -Wait -NoNewWindow -ErrorAction Stop


       $transcriptVttPath = Join-Path -Path $transcriptFolder -ChildPath "transcript.vtt"

       if (-Not (Test-Path -Path $transcriptVttPath)) {
           Write-Error "Failed to create transcript files."
           return
       }

       # Optionally remove the audio file
       Remove-Item -Path $audioPath -Force

       Write-Output "Transcript files saved to: $transcriptFolder"

       return [pscustomobject]@{
           TranscriptFolder  = $transcriptFolder
           TranscriptVttPath = $transcriptVttPath
           AudioPath         = $audioPath
           VideoPath         = $newVideoPath
       }
   }
   catch {
       Write-Error $_.Exception.ToString()
   }
}