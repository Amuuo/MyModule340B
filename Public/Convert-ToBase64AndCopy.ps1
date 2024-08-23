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