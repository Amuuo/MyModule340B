function Start-RecordingAndExtractTranscript {
    param (
        [string]$ffmpegPath = "ffmpeg",
        [ValidateSet("tiny", "small", "medium", "large", "base")][string]$model = "base",
        [string]$transcriptFolder = "$home\Videos\Meetings",
        [string]$language = "en",
        [string]$recordingName = $(Get-Date -Format "yyyyMMdd_HHmmss")
    )

    Write-Host "Opening OBS..."
    Start-OBS

    Start-Sleep -Seconds 1

    Write-Host "Connecting to OBS..."
    Connect-OBS -WebSocketToken "EhKUqZKlWsu8EykD" | Out-Null

    Start-Sleep -Seconds 1

    New-Item -ItemType Directory -Name $recordingName -Path $transcriptFolder -Force | Out-Null

    Set-OBSRecordDirectory -RecordDirectory "$transcriptFolder\$recordingName"

    Start-Sleep -Seconds 1

    Write-Host "Starting OBS recording..."
    Start-OBSRecord

    # Wait for user input to stop recording
    Write-Host "Press Enter to stop recording..."
    Read-Host

    Write-Host "Stopping OBS recording..."
    $recordingDetails = Stop-OBSRecord

    # Extract the FullName property for the recorded video file
    $videoPath = $recordingDetails.FullName

    if (-not $videoPath) {
        Write-Error "No recording found."
        return
    }

    Start-Sleep -Seconds 5


    # Generate a new file name based on the provided recordingName
    $newVideoPath = Join-Path -Path "$transcriptFolder\$recordingName" -ChildPath "$recordingName.mkv"
    Rename-Item -Path $videoPath -NewName $newVideoPath

   while ($true) {
        try {
            $stream = [System.IO.File]::Open($newVideoPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            $stream.Close()
            break
       }
       catch {
            Write-Host "Waiting for the video file to be ready..."
           Start-Sleep -Seconds 1
        }
    }

   # Invoke the transcript extraction method
    Invoke-ExtractTranscript -videoPath $newVideoPath `
        -ffmpegPath $ffmpegPath `
        -model $model `
        -transcriptFolder "$transcriptFolder\$recordingName" `
        -language $language

    Clear-Host
}

function Start-OBS {
    $obsPath = "C:\Program Files\obs-studio\bin\64bit"

    $obsProcess = Get-Process -Name "obs64" -ErrorAction SilentlyContinue
    if (-not $obsProcess) {
        Write-Output "OBS is not running. Starting OBS..."
        Start-Process -FilePath "obs64" -WorkingDirectory $obsPath -WindowStyle Minimized

        Write-Host "Waiting for OBS to start..."
        while (-not (Get-Process -Name "obs64" -ErrorAction SilentlyContinue)) {
            Start-Sleep -Seconds 1
        }
        Write-Output "OBS has started."
    } else {
        Write-Output "OBS is already running."
    }
}

