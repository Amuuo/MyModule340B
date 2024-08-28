Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 | ForEach-Object {
    . $_.FullName
}



Set-Alias -Name 'trimclip' `
    -Value 'Invoke-TrimClipboard'

Set-Alias -Name 'meeting' `
    -Value 'Start-RecordingAndExtractTranscript'

Export-ModuleMember `
    -Function (Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 | ForEach-Object { $_.BaseName }) `
    -Alias 'trimclip', 'meeting'

Import-Module obs-powershell