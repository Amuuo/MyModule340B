function Invoke-TrimClipboard {
    (Get-Clipboard -Raw) -replace '\s+', ' ' | Set-Clipboard
}

function Open-MyModule {
    cursor 'C:\Windows\System32\WindowsPowerShell\v1.0\Modules\MyModule\MyModule.psm1'
}

function Start-PorticoUI { 
    Set-Location 'C:\Projects\340Basics\src\Apexio.UI'
    npm start
}

function Start-CentralApi {
    Set-Location 'C:\Projects\340Basics\src\CentralAPI'
    dotnet run
}

function Set-LocalConfig {
    $configPath = 'C:\Projects\340Basics\src\Apexio.UI\src\assets\app-configuration.json'
    
    $configContent = (Get-Content $configPath) -replace 'https://portico-api-int0.nuvem.com/', 'http://localhost:60449/'
    $configContent = $configContent -replace 'https://api-portico-dev.nuvem.com/', 'http://localhost:60449/'
    $configContent | Set-Content -Path $configPath
}

function Restart-Synergy {
    Get-Process *synergy* | Stop-Process -Force
}

function Convert-ToBase64AndCopy {
    param(
        [string]$FilePath
    )

    # Ensure the file exists
    if (-Not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return
    }

    # Create a temporary zip file
    $tempZipPath = [System.IO.Path]::GetTempFileName() + ".zip"
    Compress-Archive -Path $FilePath -DestinationPath $tempZipPath -Force

    try {
        # Read the zip file bytes
        $fileBytes = [System.IO.File]::ReadAllBytes($tempZipPath)

        # Convert the bytes to a base64 string
        $base64String = [Convert]::ToBase64String($fileBytes)

        # Copy to clipboard
        Set-Clipboard -Value $base64String

        # Output the base64 string (optional)
        Write-Output "Base64 string copied to clipboard."
    }
    finally {
        # Cleanup: Remove the temporary zip file
        Remove-Item -Path $tempZipPath -ErrorAction SilentlyContinue
    }
}

function Invoke-AzureDevOpsApi {
    param (
        [string]$ApiUri,
        [string]$base64AuthInfo
    )
    
    $Headers = @{
        Authorization = "Basic $base64AuthInfo"
        Accept        = "application/json" 
    }

    try {
        Write-Verbose "Requesting URL: $ApiUri"
        $Response = Invoke-RestMethod -Uri $ApiUri -Headers $Headers -Method Get
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)"
        return $null
    }                    

    return $Response
}

function Get-DevOpsPullRequestStats {
    [CmdletBinding()]
    param (        
        [string]$Organization = "340BTechnology",                
        [string]$Project = "340Basics",                                
        [string]$RepositoryId = "340Basics",
        [string]$AccessToken = "zbh4kq5uu3xrgemscxnxrmyn76l2h43z6vyzyjitrqtp327jmcfa",        
        [datetime]$StartDate = (Get-Date).AddDays(-30), # Default to 30 days ago    
        [datetime]$EndDate = (Get-Date)                 # Default to today's date  # Format: YYYY-MM-DD
    )

    # Encode the PAT for authorization header
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$AccessToken"))
    $mainProgressId = 1
    $commitFetchProgressId = 2
    $commitProcessProgressId = 3
    # Helper function to call Azure DevOps REST API
    

    $UriBase = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/pullrequests?searchCriteria.status=all&searchCriteria.maxTime=$($EndDate.ToString("yyyy-MM-dd"))&searchCriteria.minTime=$($StartDate.ToString("yyyy-MM-dd"))&searchCriteria.queryTimeRangeType=closed&api-version=7.1-preview.1"
    $Skip = 0
    $Top = 100
    $AllPullRequests = @()

    do {
        $CurrentUri = "$UriBase&`$skip=$Skip&`$top=$Top"
        
        $Response = Invoke-AzureDevOpsApi -ApiUri $CurrentUri -base64AuthInfo $base64AuthInfo
        if ($Response) {
            $AllPullRequests += $Response.value
        }

        $Skip += $Top
        Write-Progress -Id $mainProgressId -Activity "Fetching Pull Requests" -Status "$Skip Pull Requests Processed"

    } while ($Response.count -ne 0)
    
    $UserStats = @{}
    $PRCount = $AllPullRequests.Count
    $ProcessedPRs = 0

    foreach ($PR in $AllPullRequests) {

        $User = $PR.createdBy.displayName

        if ($User -eq "340Basics Build Service (340BTechnology)") {
            $PRCount--
            continue
        }

        $CommitsUri = "$($PR.url)/commits?api-version=7.1-preview.1"
        $Commits = @()

        $CommitsUri = "$($PR.url)/commits?api-version=7.1-preview.1"
        $CommitResponse = Invoke-AzureDevOpsApi -ApiUri $CommitsUri
        $Commits = $CommitResponse.value

        # Initialize PR stats
        if (-not $UserStats.ContainsKey($User)) {
            $UserStats[$User] = @{
                ActivePRCount    = 0
                AbandonedPRCount = 0
                CompletedPRCount = 0
                CodeAdded        = 0
                CodeEdited       = 0
                CodeDeleted      = 0
            }
        }

        switch ($PR.status) {
            "active" { $UserStats[$User].ActivePRCount++ }
            "abandoned" { $UserStats[$User].AbandonedPRCount++ }
            "completed" { $UserStats[$User].CompletedPRCount++ }
        }            
        
        $CommitCount = $Commits.Count
        $ProcessedCommits = 0
        # Iterate over each commit to get the changes
        foreach ($Commit in $Commits) {
            $ChangesUri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/commits/$($Commit.commitId)/changes?api-version=7.1-preview.1"
            $Response = Invoke-AzureDevOpsApi -ApiUri $ChangesUri
                            
            $UserStats[$User].CodeAdded += $Response.changeCounts.Add
            $UserStats[$User].CodeEdited += $Response.changeCounts.Edit
            $UserStats[$User].CodeDeleted -= $Response.changeCounts.Delete

            $ProcessedCommits++
            Write-Progress -Id $commitProcessProgressId -ParentId $commitFetchProgressId -Activity "Processing Commits for PR: $($PR.pullRequestId)" -Status "$ProcessedCommits of $CommitCount commits processed" -PercentComplete ($ProcessedCommits / $CommitCount * 100)
        }

        $ProcessedPRs++
        Write-Progress -Id $mainProgressId -Activity "Analyzing Pull Requests" -Status "$ProcessedPRs of $PRCount PRs analyzed" -PercentComplete ($ProcessedPRs / $PRCount * 100)        
    }

    # Return stats as custom PSObject
    $UserStats.Keys | ForEach-Object {
        $User = $_
        $Stats = $UserStats[$_]

        [PSCustomObject]@{
            User         = $User
            Active       = $Stats.ActivePRCount
            Completed    = $Stats.CompletedPRCount
            Abandoned    = $Stats.AbandonedPRCount
            LinesAdded   = $Stats.CodeAdded
            LinesEdited  = $Stats.CodeEdited
            LinesDeleted = $Stats.CodeDeleted
        }
    }
}

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

function Invoke-ExtractTranscript {
    param (
        [Parameter(Mandatory = $true)][string]$videoPath,
        [Parameter(Mandatory = $false)][string]$ffmpegPath = "ffmpeg",
        [Parameter(Mandatory = $false)][string]$whisperPath = "whisper",
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

        # Check if the transcript files were created
        $transcriptTxtPath = Join-Path -Path $transcriptFolder -ChildPath "transcript.txt"
        $transcriptVttPath = Join-Path -Path $transcriptFolder -ChildPath "transcript.vtt"

        if (-Not (Test-Path -Path $transcriptTxtPath) -and -Not (Test-Path -Path $transcriptVttPath)) {
            Write-Error "Failed to create transcript files."
            return
        }

        # Optionally remove the audio file
        Remove-Item -Path $audioPath -Force

        Write-Output "Transcript files saved to: $transcriptFolder"

        return [pscustomobject]@{
            TranscriptFolder  = $transcriptFolder
            TranscriptTxtPath = $transcriptTxtPath
            TranscriptVttPath = $transcriptVttPath
            AudioPath         = $audioPath
            VideoPath         = $newVideoPath
        }
    }
    catch {
        Write-Error $_.Exception.ToString()
    }
}

function Start-RecordingAndExtractTranscript {
    param (
        [Parameter(Mandatory = $true)][string]$ffmpegPath = "ffmpeg",
        [Parameter(Mandatory = $true)][string]$whisperPath = "whisper",
        [ValidateSet("tiny", "small", "medium", "large", "base")][string]$model = "base",
        [string]$transcriptFolder = "",
        [string]$language = "en"  # Added language parameter with default value 'en'
    )

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

    # Invoke the transcript extraction method
    Invoke-ExtractTranscript -videoPath $videoPath -ffmpegPath $ffmpegPath -whisperPath $whisperPath -model $model -transcriptFolder $transcriptFolder -language $language
}



Set-Alias -Name 'trimclip' `
    -Value 'Invoke-TrimClipboard'

Set-Alias -Name 'standup' `
    -Value 'Start-RecordingAndExtractTranscript'

Export-ModuleMember -Function "Invoke-TrimClipboard", 
"Open-MyModule", 
"Start-PorticoUI", 
"Start-CentralApi", 
'Set-LocalConfig', 
'Restart-Synergy',
'Convert-ToBase64AndCopy',
'New-GifFromVideo',
'Get-DevOpsPullRequestStats',
'Extract-AudioAndRunWhisper',
'Invoke-ExtractTranscript',
'Start-RecordingAndExtractTranscript'`
    -Alias 'trimclip'