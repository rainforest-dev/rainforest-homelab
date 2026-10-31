param([Parameter(Mandatory)][string]$OutputDir)

$query = 'power.draw,temperature.gpu,utilization.gpu,memory.used,memory.total'
$target = Join-Path $OutputDir 'nvidia_gpu.prom'
$temp = "$target.tmp"
$utf8 = New-Object System.Text.UTF8Encoding($false)

while ($true) {
  $row = (& nvidia-smi "--query-gpu=$query" --format=csv,noheader,nounits 2>$null | Select-Object -First 1) -split ',\s*'
  if ($row.Count -eq 5 -and $row -notmatch 'N/A') {
    $lines = @(
      "nvidia_gpu_power_watts $($row[0])"
      "nvidia_gpu_temperature_celsius $($row[1])"
      "nvidia_gpu_utilization_percent $($row[2])"
      "nvidia_gpu_memory_used_bytes $([int64]$row[3] * 1048576)"
      "nvidia_gpu_memory_total_bytes $([int64]$row[4] * 1048576)"
    )
    [IO.File]::WriteAllText($temp, (($lines -join "`n") + "`n"), $utf8)
    Move-Item -LiteralPath $temp -Destination $target -Force
  }
  Start-Sleep -Seconds 30
}
