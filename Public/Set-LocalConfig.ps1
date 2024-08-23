function Set-LocalConfig {
   $configPath = 'C:\Projects\340Basics\src\Apexio.UI\src\assets\app-configuration.json'
   
   $configContent = (Get-Content $configPath) -replace 'https://portico-api-int0.nuvem.com/', 'http://localhost:60449/'
   $configContent = $configContent -replace 'https://api-portico-dev.nuvem.com/', 'http://localhost:60449/'
   $configContent | Set-Content -Path $configPath
}
