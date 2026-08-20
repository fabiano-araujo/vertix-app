param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$LaunchUri
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$logRoot = Join-Path $env:LOCALAPPDATA 'Vertix\DolaBridge'
[IO.Directory]::CreateDirectory($logRoot) | Out-Null
$logFile = Join-Path $logRoot 'bridge.log'

function Write-BridgeLog([string]$Message) {
    $line = '{0:o} {1}' -f [DateTime]::UtcNow, $Message
    try {
        [IO.File]::AppendAllText($logFile, $line + [Environment]::NewLine)
    } catch {}
}

function Test-DolaPort {
    try {
        $client = [Net.Sockets.TcpClient]::new()
        $client.ReceiveTimeout = 800
        $client.SendTimeout = 800
        $async = $client.BeginConnect('127.0.0.1', 3847, $null, $null)
        $ok = $async.AsyncWaitHandle.WaitOne(800, $false) -and $client.Connected
        $client.Close()
        return $ok
    } catch {
        return $false
    }
}

function Resolve-Yarn {
    $found = Get-Command yarn.cmd -ErrorAction SilentlyContinue
    if ($found -and $found.Source) { return [string]$found.Source }
    $npmYarn = Join-Path $env:APPDATA 'npm\yarn.cmd'
    if (Test-Path -LiteralPath $npmYarn) { return $npmYarn }
    throw 'Yarn nao encontrado. Instale o Yarn para subir o gerador Dola local.'
}

try {
    $parsed = [Uri]$LaunchUri
    if ($parsed.Scheme -ne 'vertixdola') {
        throw 'Link da ponte Vertix/Dola invalido.'
    }

    $workspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $serverDir = Join-Path $workspace 'server'
    if (-not (Test-Path -LiteralPath (Join-Path $serverDir 'package.json'))) {
        throw "Pasta do gerador Dola nao encontrada: $serverDir"
    }

    if (Test-DolaPort) {
        Write-BridgeLog 'Gerador Dola local ja estava no ar em 127.0.0.1:3847.'
        exit 0
    }

    $sessionFile = 'C:\Users\Fabiano\dola-launcher\dola-session.json'
    $profileRoot = 'C:\Users\Fabiano\playwright-profiles'
    $yarn = Resolve-Yarn
    Write-BridgeLog "Subindo gerador Dola local com $yarn em $serverDir"

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $yarn
    $startInfo.Arguments = 'dola:serve'
    $startInfo.WorkingDirectory = $serverDir
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.EnvironmentVariables['DOLA_SESSION_FILE'] = $sessionFile
    $startInfo.EnvironmentVariables['DOLA_PROFILE_ROOT'] = $profileRoot
    [void][Diagnostics.Process]::Start($startInfo)

    $deadline = [DateTime]::UtcNow.AddSeconds(25)
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 400
        if (Test-DolaPort) {
            Write-BridgeLog 'Gerador Dola local no ar.'
            exit 0
        }
    }
    throw 'O gerador Dola local nao abriu a porta 3847.'
} catch {
    Write-BridgeLog $_.Exception.Message
    throw
}
