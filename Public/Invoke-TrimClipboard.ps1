function Invoke-TrimClipboard {
   (Get-Clipboard -Raw) -replace '\s+', ' ' | Set-Clipboard
}