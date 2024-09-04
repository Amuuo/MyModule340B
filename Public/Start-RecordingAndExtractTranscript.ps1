function Start-RecordingAndExtractTranscript {
    param (
        [ValidateSet("tiny", "small", "medium", "large", "base")]
        [string]$model = "base",
        [string]$transcriptFolder = "$home\Videos\Meetings",
        [string]$language = "en",
        [string]$recordingName = "standup_$((Get-Date).ToString('_MM_dd_yy'))"
    )

    $script:transcriptFolder = $transcriptFolder
    $script:recordingName = $recordingName
    

    Start-OBS
        
    Read-Host -Prompt "Press Enter to stop recording..."

    Write-Host "Stopping OBS recording..."
    $recordingDetails = Stop-OBSRecord        

    if (-not $recordingDetails.FullName) {
        Write-Error "No recording found."
        return
    }

    Start-Sleep -Seconds 5
    
    $newVideoPath = Join-Path -Path "$transcriptFolder" -ChildPath "$recordingName.mkv"
    Rename-Item -Path $recordingDetails.FullName -NewName $newVideoPath

    Wait-ForFile -FilePath $newVideoPath
    
    Invoke-ExtractTranscript -videoPath $newVideoPath `
        -model $model `
        -transcriptFolder "$transcriptFolder" `
        -language $language

    Clear-Host
}

function Start-OBS {
    Write-Host "Opening OBS..."
    $obsPath = "C:\Program Files\obs-studio\bin\64bit"

    $obsProcess = Get-Process -Name "obs64" -ErrorAction SilentlyContinue
    if (-not $obsProcess) {
        Write-Output "OBS is not running. Starting OBS..."
        Start-Process -FilePath "obs64" -WorkingDirectory $obsPath -WindowStyle Minimized

        Write-Host "Waiting for OBS to start..."
        while (-not (Get-Process -Name "obs64" -ErrorAction SilentlyContinue)) {
            Start-Sleep -Seconds 1
        }
        Start-Sleep -Seconds 2
        Write-Output "OBS has started."
    }
    else {
        Write-Output "OBS is already running."
    }

    
    Write-Host "Connecting to OBS..."
    Connect-OBS -WebSocketToken "EhKUqZKlWsu8EykD" | Out-Null

    Start-Sleep -Seconds 1

    $settings = @{
        RecPath   = $script:transcriptFolder
        RecFileNameFormatting = "$script:recordingName"
        RecFormat = "mkv"
        VBitrate  = 2500
    }
    
    Write-Host "Setting OBS recording settings..."
    $settings | Format-Table
    Set-OBSOutputSettings -OutputName "simple_file_output" -OutputSettings $settings

    #Set-OBSRecordDirectory -RecordDirectory "$script:transcriptFolder"

    Start-Sleep -Seconds 1

    Write-Host "Starting OBS recording..."
    Start-OBSRecord
}

function Wait-ForFile {
    param (
        [string]$FilePath
    )
    
    while ($true) {
        try {
            $stream = [System.IO.File]::Open(
                $FilePath, 
                [System.IO.FileMode]::Open, 
                [System.IO.FileAccess]::Read, 
                [System.IO.FileShare]::None
            )
            $stream.Close()
            break
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }
}

