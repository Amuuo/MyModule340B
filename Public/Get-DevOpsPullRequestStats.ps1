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