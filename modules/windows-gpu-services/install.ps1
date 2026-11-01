param(
  [Parameter(Mandatory)][string]$OllamaVersion,
  [Parameter(Mandatory)][string]$OllamaSha256,
  [Parameter(Mandatory)][string]$OllamaModel,
  [Parameter(Mandatory)][string]$WhisperModel,
  [Parameter(Mandatory)][string]$ComfyuiDir
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$user = $env:USERNAME
$servicesDir = Join-Path $env:USERPROFILE 'homelab-services'
$whisperDir = Join-Path $servicesDir 'whisper'
$ollamaExe = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'
$torchLib = Join-Path $ComfyuiDir '.venv\Lib\site-packages\torch\lib'

function Set-StartupTask([string]$Name, [string]$Command, [string]$WorkingDirectory) {
  $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$Command`"" -WorkingDirectory $WorkingDirectory
  $trigger = New-ScheduledTaskTrigger -AtStartup
  $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType S4U -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
  Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
}

function Stop-Listener([int]$Port) {
  $owners = (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue).OwningProcess
  foreach ($owner in $owners) { Stop-Process -Id $owner -Force -ErrorAction SilentlyContinue }
}

function Wait-Http([string]$Url, [int]$Seconds) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    try { Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 | Out-Null; return } catch { Start-Sleep -Seconds 5 }
  }
  throw "$Url did not answer within $Seconds s"
}

New-Item -ItemType Directory -Force -Path $whisperDir | Out-Null

foreach ($rule in @(@{ Name = 'ComfyUI 8188 Private LAN'; Port = 8188 }, @{ Name = 'Ollama 11434 Private LAN'; Port = 11434 }, @{ Name = 'Whisper 8000 Private LAN'; Port = 8000 })) {
  Remove-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -Action Allow -Protocol TCP -LocalPort $rule.Port -Profile Private -RemoteAddress LocalSubnet | Out-Null
}

$logDir = Join-Path $ComfyuiDir 'logs'
$python = Join-Path $ComfyuiDir '.venv\Scripts\python.exe'
Set-StartupTask 'ComfyUI' "`"$python`" main.py --listen 0.0.0.0 --port 8188 >> `"$logDir\out.log`" 2>> `"$logDir\err.log`"" $ComfyuiDir

Stop-ScheduledTask -TaskName 'Ollama' -ErrorAction SilentlyContinue
Stop-Listener 11434
Get-Process -Name 'ollama app', 'ollama' -ErrorAction SilentlyContinue | Stop-Process -Force
$setup = Join-Path $env:TEMP "OllamaSetup-$OllamaVersion.exe"
Invoke-WebRequest -Uri "https://github.com/ollama/ollama/releases/download/$OllamaVersion/OllamaSetup.exe" -OutFile $setup -UseBasicParsing
if ((Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash -ne $OllamaSha256.ToUpperInvariant()) {
  Remove-Item -LiteralPath $setup
  throw "Ollama installer checksum mismatch for $OllamaVersion"
}
$process = Start-Process -FilePath $setup -Wait -PassThru -ArgumentList '/VERYSILENT', '/NORESTART', '/SUPPRESSMSGBOXES'
Remove-Item -LiteralPath $setup
if ($process.ExitCode -ne 0) { throw "Ollama installer exited with $($process.ExitCode)" }
Get-Process -Name 'ollama app', 'ollama' -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath('Startup')) 'Ollama.lnk') -ErrorAction SilentlyContinue
Set-Content -LiteralPath (Join-Path $servicesDir 'ollama.cmd') -Encoding Ascii -Value @(
  '@echo off'
  'set OLLAMA_HOST=0.0.0.0:11434'
  "`"$ollamaExe`" serve >> `"$servicesDir\ollama.log`" 2>&1"
)
Set-StartupTask 'Ollama' (Join-Path $servicesDir 'ollama.cmd') $servicesDir
Start-ScheduledTask -TaskName 'Ollama'
Wait-Http 'http://127.0.0.1:11434/api/version' 60

Stop-ScheduledTask -TaskName 'Whisper' -ErrorAction SilentlyContinue
Stop-Listener 8000
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'main.py') -Destination $whisperDir -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'pyproject.toml') -Destination $whisperDir -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uv.lock') -Destination $whisperDir -Force
$venvPython = Join-Path $whisperDir '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPython)) { & python -m venv (Join-Path $whisperDir '.venv') }
$ErrorActionPreference = 'Continue'
& $venvPython -m pip install --quiet --disable-pip-version-check uv *> (Join-Path $servicesDir 'whisper-pip.log')
$env:VIRTUAL_ENV = Join-Path $whisperDir '.venv'
Push-Location $whisperDir
& $venvPython -m uv sync --frozen --no-install-project --active *>> (Join-Path $servicesDir 'whisper-pip.log')
$syncExit = $LASTEXITCODE
Pop-Location
$ErrorActionPreference = 'Stop'
if ($syncExit -ne 0) { throw "uv sync failed, see whisper-pip.log" }
New-Item -ItemType Directory -Force -Path 'C:\models' | Out-Null
icacls 'C:\models' /grant "${user}:(OI)(CI)M" | Out-Null
Set-Content -LiteralPath (Join-Path $servicesDir 'whisper.cmd') -Encoding Ascii -Value @(
  '@echo off'
  "set PATH=$torchLib;%PATH%"
  "set WHISPER_MODEL=$WhisperModel"
  'set CUDA_AVAILABLE=true'
  "`"$venvPython`" -m uvicorn main:app --host 0.0.0.0 --port 8000 >> `"$servicesDir\whisper.log`" 2>&1"
)
Set-StartupTask 'Whisper' (Join-Path $servicesDir 'whisper.cmd') $whisperDir
Start-ScheduledTask -TaskName 'Whisper'
Wait-Http 'http://127.0.0.1:8000/health' 900

$ErrorActionPreference = 'Continue'
$env:OLLAMA_HOST = '127.0.0.1:11434'
& $ollamaExe pull $OllamaModel *> (Join-Path $servicesDir 'ollama-pull.log')
if ($LASTEXITCODE -ne 0) { throw "ollama pull failed, see ollama-pull.log" }
