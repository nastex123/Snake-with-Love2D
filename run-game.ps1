<#
PowerShell launcher for Love2D project.
Run from the project folder or by double-clicking this script (if execution policy allows).
#>
Push-Location $PSScriptRoot
$love = "C:\Program Files\LOVE\love.exe"
if (Test-Path $love) {
    & $love . 2>&1 | Tee-Object -FilePath "error.log"
} else {
    Write-Error "LOVE not found at $love"
    love . 2>&1 | Tee-Object -FilePath "error.log"
}
Pop-Location
