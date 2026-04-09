param(
  [string]$ProjectRoot = "D:\projects\cursor\RTS_p5",
  [string]$ProcessingExe = "D:\Program Files\Processing\Processing.exe"
)

$ErrorActionPreference = "Stop"

$buildScript = Join-Path $ProjectRoot "build.ps1"
$outputDir = Join-Path $ProjectRoot "_cli_build_out"

if (!(Test-Path $buildScript)) {
  throw "Missing build script: $buildScript"
}

Write-Host "[SMOKE] Build start..."
& powershell -ExecutionPolicy Bypass -File $buildScript -ProcessingExe $ProcessingExe
if ($LASTEXITCODE -ne 0) {
  throw "[SMOKE] build.ps1 failed with code $LASTEXITCODE"
}

if (!(Test-Path $outputDir)) {
  throw "[SMOKE] Output folder missing: $outputDir"
}

$files = Get-ChildItem -Path $outputDir -Recurse -File
if ($files.Count -le 0) {
  throw "[SMOKE] Output folder is empty: $outputDir"
}

$candidate = $files | Where-Object {
  $_.Name -match "\.(jar|exe)$" -or $_.Name -like "RTS_p5*"
} | Select-Object -First 1

if ($null -eq $candidate) {
  throw "[SMOKE] No runnable artifact candidate found under: $outputDir"
}

Write-Host "[SMOKE] Build artifact found: $($candidate.FullName)"
Write-Host "[SMOKE] PASS"
