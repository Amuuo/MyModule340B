function Invoke-ExtractTranscript {
    param (
        [Parameter(Mandatory = $true)][string]$videoPath,
        [Parameter(Mandatory = $false)][string]$ffmpegPath = "ffmpeg",        
        [ValidateSet("tiny", "small", "medium", "large", "base")][string]$model = "base",
        [string]$transcriptFolder = "",
        [string]$language = "en"
    )

    # Assign parameters to script-level variables
    $script:videoPath = $videoPath
    $script:ffmpegPath = $ffmpegPath    
    $script:model = $model
    $script:transcriptFolder = $transcriptFolder
    $script:language = $language

    # Check if the video file exists
    if (-Not (Test-Path -Path $script:videoPath)) {
        Write-Error "The specified video file does not exist: $script:videoPath"
        return
    }

    # Create transcript folder if not provided
    $script:transcriptFolder = Create-TranscriptFolder

    # Move the video file to the transcript folder
    $script:newVideoPath = Move-VideoFile

    # Define the output audio file path
    $script:audioPath = [System.IO.Path]::ChangeExtension($script:newVideoPath, ".mp3")

    try {
        # Extract audio from the video file using FFmpeg
        Extract-Audio

        # Run Whisper on the extracted audio file and save output to transcript files
        $transcriptPaths = Run-Whisper

        # Optionally remove the audio file
        if (Test-Path -Path $script:audioPath) {
            Remove-Item -Path $script:audioPath -Force
        }

        if (Test-Path -Path $script:newVideoPath) {
            Remove-Item -Path $script:newVideoPath -Force
        }

        Write-Output "Transcript files saved to: $script:transcriptFolder"

        return $transcriptPaths
    }
    catch {
        Write-Error $_.Exception.ToString()
    }
}

function Create-TranscriptFolder {
    $videoName = [System.IO.Path]::GetFileNameWithoutExtension($script:videoPath)
   
    if (-not $script:transcriptFolder) {
        $script:transcriptFolder = Join-Path -Path (Get-Location) -ChildPath "${videoName}"
    }

    if (-Not (Test-Path -Path $script:transcriptFolder -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $script:transcriptFolder -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error "Failed to create transcript directory: $_"
            return
        }
    }

    return $script:transcriptFolder
}

function Move-VideoFile {
    $newVideoPath = Join-Path -Path $script:transcriptFolder -ChildPath (Get-Item $script:videoPath).Name
    try {
        Move-Item -Path $script:videoPath -Destination $newVideoPath -Force
    }
    catch {
        Write-Error "Failed to move the video file to the transcript directory: $_"
        return
    }

    return $newVideoPath
}

function Extract-Audio {
    $ffmpegCommand = "-i `"$script:newVideoPath`" -q:a 0 -map a `"$script:audioPath`""
    Write-Output "Extracting audio from video..."
    Start-Process `
        -FilePath $script:ffmpegPath `
        -ArgumentList $ffmpegCommand `
        -Wait `
        -NoNewWindow -ErrorAction Stop

    # Check if the audio file was created
    if (-Not (Test-Path -Path $script:audioPath)) {
        Write-Error "Failed to extract audio."
        return
    }
}

function Run-Whisper {
    $whisperCommand = @(
       "`"$script:audioPath`"",
       "--model", $script:model,
       "--output_dir", "`"$script:transcriptFolder`"",
       "--language", $script:language,
       "--device", "cuda",
       "--output_format", "vtt"
   ) -join " "  # Join the array into a single string

    Write-Output "Running Whisper on the extracted audio using model '$script:model' and language '$script:language'..."
    Start-Process `
        -FilePath "whisper" `
        -ArgumentList $whisperCommand `
        -Wait `
        -NoNewWindow `
        -ErrorAction Stop

    Invoke-Item -Path $script:transcriptFolder    
}
