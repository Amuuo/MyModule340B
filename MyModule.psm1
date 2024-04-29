function Invoke-TrimClipboard {
    (Get-Clipboard -Raw) -replace '\s+', ' ' | Set-Clipboard
}

function Open-MyModule {
    code 'C:\Windows\System32\WindowsPowerShell\v1.0\Modules\MyModule\MyModule.psm1'
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

function Get-DevOpsPullRequestStats {
    [CmdletBinding()]
    param (        
        [string]$Organization = "340BTechnology",                
        [string]$Project = "340Basics",                
        #[string]$RepositoryId = "e3d9b748-855e-4867-8085-b065f9fea549",                
        [string]$RepositoryId = "340Basics",
        [string]$AccessToken = "zbh4kq5uu3xrgemscxnxrmyn76l2h43z6vyzyjitrqtp327jmcfa",        
        [datetime]$StartDate = (Get-Date).AddDays(-30), # Default to 30 days ago    
        [datetime]$EndDate = (Get-Date)                  # Default to today's date  # Format: YYYY-MM-DD
    )

    # Encode the PAT for authorization header
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$AccessToken"))
    $mainProgressId = 1
    $commitFetchProgressId = 2
    $commitProcessProgressId = 3
    # Helper function to call Azure DevOps REST API
    function Invoke-AzureDevOpsApi {
        param (
            [string]$ApiUri
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

    $UriBase = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/pullrequests?searchCriteria.status=all&searchCriteria.maxTime=$($EndDate.ToString("yyyy-MM-dd"))&searchCriteria.minTime=$($StartDate.ToString("yyyy-MM-dd"))&searchCriteria.queryTimeRangeType=closed&api-version=7.1-preview.1"
    $Skip = 0
    $Top = 100
    $AllPullRequests = @()

    do {
        $CurrentUri = "$UriBase&`$skip=$Skip&`$top=$Top"
        
        $Response = Invoke-AzureDevOpsApi -ApiUri $CurrentUri
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
        $CommitSkip = 0
        $CommitTop = 5
        $Commits = @()


        $CommitsUri = "$($PR.url)/commits?api-version=7.1-preview.1"
        $CommitResponse = Invoke-AzureDevOpsApi -ApiUri $CommitsUri
        $Commits = $CommitResponse.value
        # do {
        #     $CommitsUri = "$($PR.url)/commits?api-version=7.1-preview.1&`$skip=$CommitSkip&`$top=$CommitTop"
        #     $CommitResponse = Invoke-AzureDevOpsApi -ApiUri $CommitsUri
            
        #     if ($CommitResponse -and $CommitResponse.value) {
        #         $Commits += $CommitResponse.value
        #     }
            
        #     $CommitSkip += $CommitTop

        #     Write-Progress -Id $commitFetchProgressId -ParentId $mainProgressId -Activity "Fetching Commits for PR: $($PR.pullRequestId)" -Status "Processed $Commits Commits" -PercentComplete ($CommitSkip / ($CommitResponse.count + $CommitSkip) * 100)
    
        # } while ($CommitResponse -and $CommitResponse.count -eq 5)

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

Export-ModuleMember -Function Get-DevOpsPullRequestStats





Set-Alias -Name 'trimclip' `
    -Value 'Invoke-TrimClipboard'

Export-ModuleMember -Function "Invoke-TrimClipboard", 
"Open-MyModule", 
"Start-PorticoUI", 
"Start-CentralApi", 
'Set-LocalConfig', 
'Restart-Synergy',
'Convert-ToBase64AndCopy',
"Get-DevOpsPullRequestStats"`
    -Alias 'trimclip'