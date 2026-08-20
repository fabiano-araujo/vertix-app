$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bridge = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'VertixCodexBridge.ps1')).Path
$skillSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'skill-package\vertix-reference-images')).Path
$codexRoot = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    Join-Path $env:USERPROFILE '.codex'
} else {
    $env:CODEX_HOME
}
$skillRoot = Join-Path $codexRoot 'skills'
$skillTarget = Join-Path $skillRoot 'vertix-reference-images'
$protocolRoot = 'HKCU:\Software\Classes\vertixcodex'
$commandKey = Join-Path $protocolRoot 'shell\open\command'

New-Item -Path $protocolRoot -Force | Out-Null
Set-Item -LiteralPath $protocolRoot -Value 'URL:Vertix Codex Bridge'
New-ItemProperty -LiteralPath $protocolRoot -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
New-Item -Path $commandKey -Force | Out-Null
$command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" "%1"' -f $bridge
Set-Item -LiteralPath $commandKey -Value $command

[IO.Directory]::CreateDirectory($skillRoot) | Out-Null
Copy-Item -LiteralPath $skillSource -Destination $skillRoot -Recurse -Force

Write-Output "Protocolo vertixcodex instalado para: $bridge"
Write-Output "Skill Vertix instalada em: $skillTarget"
