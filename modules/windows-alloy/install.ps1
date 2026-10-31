param(
  [Parameter(Mandatory)][string]$Version,
  [Parameter(Mandatory)][string]$Sha256,
  [Parameter(Mandatory)][string]$PrometheusUrl,
  [Parameter(Mandatory)][string]$LokiUrl,
  [Parameter(Mandatory)][string]$Machine,
  [Parameter(Mandatory)][string]$ComfyuiLog
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$alloyDir = 'C:\Program Files\GrafanaLabs\Alloy'
$homelabDir = Join-Path $env:ProgramData 'homelab'
$taskName = 'HomelabGpuMetrics'

$installer = Join-Path $env:TEMP "alloy-installer-$Version.exe"
$url = "https://github.com/grafana/alloy/releases/download/$Version/alloy-installer-windows-amd64.exe"
Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $Sha256.ToUpperInvariant()) {
  Remove-Item -LiteralPath $installer
  throw "alloy installer checksum mismatch for $Version"
}

$environment = @(
  "PROMETHEUS_REMOTE_WRITE_URL=$PrometheusUrl"
  "LOKI_PUSH_URL=$LokiUrl"
  "ALLOY_MACHINE=$Machine"
  "COMFYUI_LOG_PATH=$ComfyuiLog"
) -join '\0'

$process = Start-Process -FilePath $installer -Wait -PassThru -ArgumentList @(
  '/S', '/FORCEREGISTRY=yes', '/DISABLEREPORTING=yes', '/DISABLEPROFILING=yes', "/ENVIRONMENT=`"$environment`""
)
Remove-Item -LiteralPath $installer
if ($process.ExitCode -ne 0) { throw "alloy installer exited with $($process.ExitCode)" }

New-Item -ItemType Directory -Force -Path $homelabDir, (Join-Path $alloyDir 'textfile_inputs') | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'alloy.river') -Destination (Join-Path $alloyDir 'config.alloy') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'gpu-metrics.ps1') -Destination $homelabDir -Force

$arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$homelabDir\gpu-metrics.ps1`" -OutputDir `"$alloyDir\textfile_inputs`""
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Restart-Service -Name Alloy
Start-Sleep -Seconds 5
if ((Get-Service -Name Alloy).Status -ne 'Running') { throw 'Alloy service did not stay running' }
