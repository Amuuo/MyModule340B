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