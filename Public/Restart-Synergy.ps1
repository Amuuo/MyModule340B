function Restart-Synergy {
   Get-Process *synergy* | Stop-Process -Force
}