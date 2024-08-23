function Start-RecordingAndExtractTranscript {
   param (
       [string]$ffmpegPath = "ffmpeg",
       [string]$whisperPath = "whisper",
       [ValidateSet("tiny", "small", "medium", "large", "base")][string]$model = "base",
       [string]$transcriptFolder = "$home\Videos\StandUp",
       [string]$language = "en" # Added language parameter with default value 'en'
   )    

   # Ensure OBS is connected before starting the recording   
   Write-Host "Connecting to OBS..."
   Connect-OBS -WebSocketToken "EhKUqZKlWsu8EykD"                 

   Set-OBSRecordDirectory -RecordDirectory $transcriptFolder
   # Start recording in OBS
   Write-Host "Starting OBS recording..."
   Start-OBSRecord

   # Wait for user input to stop recording
   Write-Host "Press Enter to stop recording..."
   Read-Host

   # Stop recording and get the output details
   Write-Host "Stopping OBS recording..."
   $recordingDetails = Stop-OBSRecord

   # Extract the FullName property for the recorded video file
   $videoPath = $recordingDetails.FullName

   if (-not $videoPath) {
       Write-Error "No recording found."
       return
   }

   while ($true) {
       try {
           $stream = [System.IO.File]::Open($videoPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
           $stream.Close()
           break
       }
       catch {
           Write-Host "Waiting for the video file to be ready..."
           Start-Sleep -Seconds 1
       }
   }

   # Invoke the transcript extraction method
   Invoke-ExtractTranscript -videoPath $videoPath `
       -ffmpegPath $ffmpegPath `
       -whisperPath $whisperPath `
       -model $model `
       -transcriptFolder $transcriptFolder `
       -language $language
}
