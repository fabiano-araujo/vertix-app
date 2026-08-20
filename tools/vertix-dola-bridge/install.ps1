$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bridge = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'VertixDolaBridge.ps1')).Path
$protocolRoot = 'HKCU:\Software\Classes\vertixdola'
$commandKey = Join-Path $protocolRoot 'shell\open\command'

New-Item -Path $protocolRoot -Force | Out-Null
Set-Item -LiteralPath $protocolRoot -Value 'URL:Vertix Dola Bridge'
New-ItemProperty -LiteralPath $protocolRoot -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
New-Item -Path $commandKey -Force | Out-Null
$command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" "%1"' -f $bridge
Set-Item -LiteralPath $commandKey -Value $command

Write-Output "Protocolo vertixdola instalado para: $bridge"
