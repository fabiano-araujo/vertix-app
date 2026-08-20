param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$LaunchUri
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$apiBase = ''
$jobId = ''
$token = ''
$mutex = $null
$mutexAcquired = $false
$bridgeFailed = $false
$logRoot = Join-Path $env:LOCALAPPDATA 'Vertix\CodexBridge'
[IO.Directory]::CreateDirectory($logRoot) | Out-Null
$diagnosticLog = Join-Path $logRoot 'bridge.log'

function Write-BridgeLog([string]$Message) {
    $safeMessage = $Message
    if (-not [string]::IsNullOrWhiteSpace($script:token)) {
        $safeMessage = $safeMessage.Replace($script:token, '[credencial removida]')
    }
    $line = '{0:o} {1}' -f [DateTime]::UtcNow, $safeMessage
    try {
        [IO.File]::AppendAllText($script:diagnosticLog, $line + [Environment]::NewLine)
    } catch {
        # A geracao nao deve falhar apenas porque o log local esta bloqueado.
    }
}

function Read-QueryParameters([Uri]$ParsedUri) {
    $values = @{}
    $query = $ParsedUri.Query.TrimStart('?')
    if ([string]::IsNullOrWhiteSpace($query)) { return $values }
    foreach ($part in $query.Split('&')) {
        $pair = $part.Split('=', 2)
        $key = [Uri]::UnescapeDataString($pair[0].Replace('+', ' '))
        $value = if ($pair.Count -gt 1) {
            [Uri]::UnescapeDataString($pair[1].Replace('+', ' '))
        } else { '' }
        $values[$key] = $value
    }
    return $values
}

function Quote-ProcessArgument([string]$Value) {
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

function Resolve-CodexCommand {
    $candidates = @(
        Get-Command codex.cmd -All -ErrorAction SilentlyContinue |
            Where-Object { $_.Source -and (Test-Path -LiteralPath $_.Source -PathType Leaf) }
    )
    $npmCandidate = Join-Path $env:APPDATA 'npm\codex.cmd'
    if (Test-Path -LiteralPath $npmCandidate -PathType Leaf) {
        $candidates += Get-Item -LiteralPath $npmCandidate
    }
    $selected = $candidates | Select-Object -First 1
    if ($null -eq $selected) {
        throw 'O Codex CLI publico nao foi encontrado. Reinstale a ponte depois de instalar o Codex CLI.'
    }
    if ($selected -is [IO.FileInfo]) { return [string]$selected.FullName }
    return [string]$selected.Source
}

function Send-BridgeStatus(
    [string]$Status,
    [string]$Message,
    [string]$ThreadId = ''
) {
    if ([string]::IsNullOrWhiteSpace($script:apiBase) -or
        [string]::IsNullOrWhiteSpace($script:jobId) -or
        [string]::IsNullOrWhiteSpace($script:token)) {
        return $false
    }
    $body = @{
        status = $Status
        message = $Message
    }
    if (-not [string]::IsNullOrWhiteSpace($ThreadId)) {
        $body['threadId'] = $ThreadId
    }
    try {
        Invoke-RestMethod `
            -Method Post `
            -Uri "$($script:apiBase.TrimEnd('/'))/codex/reference-image-jobs/$($script:jobId)/bridge-status" `
            -Headers @{ Authorization = "Bearer $($script:token)" } `
            -ContentType 'application/json' `
            -Body ($body | ConvertTo-Json -Compress) `
            -TimeoutSec 15 | Out-Null
        return $true
    } catch {
        Write-BridgeLog "Nao foi possivel registrar o status $Status na API: $($_.Exception.Message)"
        return $false
    }
}

try {
    $parsed = [Uri]$LaunchUri
    if ($parsed.Scheme -ne 'vertixcodex' -or $parsed.Host -ne 'reference-images') {
        throw 'Link da ponte Vertix/Codex invalido.'
    }
    $query = Read-QueryParameters $parsed
    $apiBase = [string]$query['apiBase']
    $jobId = [string]$query['jobId']
    $token = [string]$query['token']

    $apiUri = [Uri]$apiBase
    $isProductionApi = $apiUri.Scheme -eq 'https' -and $apiUri.Host -eq 'vertix-api.snapdark.com'
    $isLocalApi = $apiUri.Scheme -eq 'http' -and $apiUri.Host -in @('127.0.0.1', 'localhost')
    if (-not ($isProductionApi -or $isLocalApi)) {
        throw 'A ponte recusou uma origem de API nao autorizada.'
    }
    if ($jobId -notmatch '^[1-9][0-9]*$') { throw 'ID de job invalido.' }
    if ($token -notmatch '^[A-Za-z0-9_-]{40,96}$') { throw 'Token de job invalido.' }

    $workspace = [string]$query['workspace']
    if ([string]::IsNullOrWhiteSpace($workspace) -or -not (Test-Path -LiteralPath $workspace -PathType Container)) {
        $workspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    } else {
        $workspace = (Resolve-Path -LiteralPath $workspace).Path
    }

    $mutex = [Threading.Mutex]::new($false, "Local\VertixCodexReferenceJob-$jobId")
    $mutexAcquired = $mutex.WaitOne(0)
    if (-not $mutexAcquired) {
        Write-BridgeLog "Job $jobId ja possui uma ponte em execucao."
        exit 0
    }

    $logFile = Join-Path $logRoot "reference-job-$jobId.jsonl"
    $errorLogFile = Join-Path $logRoot "reference-job-$jobId.stderr.log"
    Write-BridgeLog "Iniciando ponte para o job $jobId."
    Send-BridgeStatus 'STARTING' 'Ponte local iniciada; criando uma tarefa no Codex' | Out-Null

    $codexExecutable = Resolve-CodexCommand
    Write-BridgeLog "Codex CLI selecionado: $codexExecutable"

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $codexExecutable
    $arguments = @(
        'exec',
        '--json',
        '--enable', 'image_generation',
        '-C', $workspace,
        '-s', 'danger-full-access',
        '-c', 'approval_policy="never"',
        '-'
    )
    $startInfo.Arguments = ($arguments | ForEach-Object { Quote-ProcessArgument $_ }) -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['VERTIX_REFERENCE_API_BASE'] = $apiBase.TrimEnd('/')
    $startInfo.EnvironmentVariables['VERTIX_REFERENCE_JOB_ID'] = $jobId
    $startInfo.EnvironmentVariables['VERTIX_REFERENCE_JOB_TOKEN'] = $token

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'Nao foi possivel iniciar o Codex.' }

    $prompt = 'Use $vertix-reference-images para processar agora o job de imagens Vertix fornecido pelas variaveis de ambiente. Gere as imagens reais com $imagegen, envie cada uma assim que terminar e continue ate concluir todas.'
    $process.StandardInput.WriteLine($prompt)
    $process.StandardInput.Close()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $threadStarted = $false
    while (-not $process.StandardOutput.EndOfStream) {
        $line = $process.StandardOutput.ReadLine()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        [IO.File]::AppendAllText($logFile, $line + [Environment]::NewLine)
        if ($threadStarted) { continue }
        try {
            $event = $line | ConvertFrom-Json
            if ($event.type -eq 'thread.started' -and $event.thread_id -match '^[0-9a-fA-F-]{32,40}$') {
                $threadStarted = $true
                Send-BridgeStatus `
                    'STARTED' `
                    'Tarefa iniciada no Codex; aguardando a primeira imagem' `
                    ([string]$event.thread_id) | Out-Null
                Write-BridgeLog "Tarefa $($event.thread_id) criada para o job $jobId."
                if ($env:VERTIX_CODEX_BRIDGE_NO_OPEN -ne '1') {
                    Start-Process "codex://threads/$($event.thread_id)"
                }
            }
        } catch {
            # Linhas nao JSON nao impedem a execucao do agente.
        }
    }
    $process.WaitForExit()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        [IO.File]::AppendAllText($errorLogFile, $stderr)
    }

    if ($process.ExitCode -ne 0) {
        $lastError = ($stderr -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1)
        $detail = if ($lastError) { ": $lastError" } else { '' }
        throw "O Codex encerrou com codigo $($process.ExitCode)$detail"
    }
    if (-not $threadStarted) {
        throw 'O Codex encerrou sem criar uma tarefa visivel.'
    }
    Write-BridgeLog "Ponte do job $jobId concluida."
} catch {
    $bridgeFailed = $true
    $failureMessage = $_.Exception.Message
    if (-not [string]::IsNullOrWhiteSpace($token)) {
        $failureMessage = $failureMessage.Replace($token, '[credencial removida]')
    }
    Write-BridgeLog "Falha no job $jobId`: $failureMessage"
    Send-BridgeStatus 'FAILED' "Falha ao iniciar o Codex: $failureMessage" | Out-Null
} finally {
    if ($null -ne $mutex) {
        if ($mutexAcquired) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

if ($bridgeFailed) { exit 1 }
