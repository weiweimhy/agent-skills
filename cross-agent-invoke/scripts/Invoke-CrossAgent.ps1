#requires -Version 7.0
[CmdletBinding(DefaultParameterSetName = "Invoke")]
param(
    [Parameter(ParameterSetName = "Invoke", Mandatory)]
    [Parameter(ParameterSetName = "List")]
    [string]$Target,

    [Parameter(ParameterSetName = "List", Mandatory)]
    [switch]$ListAgents,

    [Parameter(ParameterSetName = "List")]
    [switch]$CheckVersion,

    [Parameter(ParameterSetName = "Invoke")]
    [string]$Prompt,

    [Parameter(ParameterSetName = "Invoke")]
    [string]$PromptFile,

    [Parameter(ParameterSetName = "Invoke")]
    [string]$WorkingDir = ".",

    [Parameter(ParameterSetName = "Invoke")]
    [ValidateSet("read-only", "workspace-write")]
    [string]$Mode = "read-only",

    [Parameter(ParameterSetName = "Invoke")]
    [string]$Model,

    [Parameter(ParameterSetName = "Invoke")]
    [string]$Effort,

    [Parameter(ParameterSetName = "Invoke")]
    [string]$SessionId,

    [Parameter(ParameterSetName = "Invoke")]
    [ValidateSet("text", "json")]
    [string]$OutputFormat = "text",

    [Parameter(ParameterSetName = "Invoke")]
    [ValidateRange(10, 3600)]
    [int]$TimeoutSeconds = 300,

    [Parameter(ParameterSetName = "Invoke")]
    [ValidateRange(1, 5)]
    [int]$MaxDepth = 1,

    [Parameter(ParameterSetName = "Invoke")]
    [string]$Caller,

    [Parameter(ParameterSetName = "Invoke")]
    [string]$OutputFile,

    [Parameter(ParameterSetName = "Invoke")]
    [switch]$Worktree,

    [Parameter(ParameterSetName = "Invoke")]
    [switch]$KeepSession,

    [Parameter(ParameterSetName = "Invoke")]
    [switch]$RawPrompt,

    [Parameter(ParameterSetName = "Invoke")]
    [switch]$AllowSelf,

    [Parameter(ParameterSetName = "Invoke")]
    [switch]$AllowLoop,

    [Parameter(ParameterSetName = "Invoke")]
    [switch]$DryRun,

    [Parameter(ParameterSetName = "Invoke")]
    [string[]]$ExtraArgs = @(),

    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function Resolve-AgentName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Agent target cannot be empty. Expected one of: codex, antigravity, workbuddy, claude."
    }
    switch ($Name.Trim().ToLowerInvariant()) {
        "codex"       { return "codex" }
        "codex-cli"   { return "codex" }
        "antigravity" { return "antigravity" }
        "agy"         { return "antigravity" }
        "workbuddy"   { return "workbuddy" }
        "codebuddy"   { return "workbuddy" }
        "cbc"         { return "workbuddy" }
        "claude"      { return "claude" }
        "claude-code" { return "claude" }
        default       { throw "Unsupported agent target: '$Name'. Expected one of: codex, antigravity, workbuddy, claude." }
    }
}

function Get-CurrentCallerHost {
    if (-not [string]::IsNullOrWhiteSpace($env:ANTIGRAVITY_CONVERSATION_ID) -or
        -not [string]::IsNullOrWhiteSpace($env:ANTIGRAVITY_AGENT)) {
        return "antigravity"
    }
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_THREAD_ID) -or
        -not [string]::IsNullOrWhiteSpace($env:CODEX_SANDBOX) -or
        -not [string]::IsNullOrWhiteSpace($env:CODEX_MANAGED_BY_NPM)) {
        return "codex"
    }
    if (-not [string]::IsNullOrWhiteSpace($env:WORKBUDDY_SESSION_ID) -or
        -not [string]::IsNullOrWhiteSpace($env:CODEBUDDY_SESSION_ID) -or
        -not [string]::IsNullOrWhiteSpace($env:WORKBUDDY_HOME)) {
        return "workbuddy"
    }
    if (-not [string]::IsNullOrWhiteSpace($env:CLAUDECODE) -or
        -not [string]::IsNullOrWhiteSpace($env:CLAUDE_CODE_ENTRYPOINT)) {
        return "claude"
    }
    return "unknown"
}

function Find-AgentExecutable {
    param([Parameter(Mandatory)][string]$CanonicalTarget)

    $envVarMap = @{
        codex       = "CROSS_AGENT_CODEX_BIN"
        antigravity = "CROSS_AGENT_ANTIGRAVITY_BIN"
        workbuddy   = "CROSS_AGENT_WORKBUDDY_BIN"
        claude      = "CROSS_AGENT_CLAUDE_BIN"
    }

    $envVarName = $envVarMap[$CanonicalTarget]
    $overridePath = [Environment]::GetEnvironmentVariable($envVarName)
    if (-not [string]::IsNullOrWhiteSpace($overridePath)) {
        if (Test-Path -LiteralPath $overridePath -PathType Leaf) {
            return [PSCustomObject]@{
                Available  = $true
                Executable = (Resolve-Path -LiteralPath $overridePath).Path
                Source     = "env:$envVarName"
                EnvVar     = $envVarName
            }
        }
        return [PSCustomObject]@{
            Available  = $false
            Executable = $null
            Source     = "env:$envVarName (missing: $overridePath)"
            EnvVar     = $envVarName
        }
    }

    $pathCommands = switch ($CanonicalTarget) {
        "codex"       { @("codex") }
        "antigravity" { @("agy") }
        "workbuddy"   { @("codebuddy", "cbc", "workbuddy") }
        "claude"      { @("claude") }
    }

    foreach ($cmdName in $pathCommands) {
        $found = Get-Command -Name $cmdName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found -and -not [string]::IsNullOrWhiteSpace($found.Source)) {
            return [PSCustomObject]@{
                Available  = $true
                Executable = $found.Source
                Source     = "PATH:$cmdName"
                EnvVar     = $envVarName
            }
        }
    }

    $homeDir = $HOME
    $localApp = $env:LOCALAPPDATA
    $roamingApp = $env:APPDATA
    $progFiles = $env:ProgramFiles

    $candidates = New-Object System.Collections.Generic.List[string]
    switch ($CanonicalTarget) {
        "codex" {
            $candidates.Add((Join-Path $homeDir ".codex/.sandbox-bin/codex.exe"))
            $candidates.Add((Join-Path $homeDir ".codex/plugins/.plugin-appserver/codex.exe"))
            if ($roamingApp) { $candidates.Add((Join-Path $roamingApp "npm/codex.cmd")) }
            $candidates.Add((Join-Path $homeDir ".local/bin/codex.exe"))
            $candidates.Add((Join-Path $homeDir ".local/bin/codex"))
        }
        "antigravity" {
            if ($localApp) { $candidates.Add((Join-Path $localApp "Programs/Antigravity CLI/agy.exe")) }
            $candidates.Add((Join-Path $homeDir ".local/bin/agy.exe"))
            $candidates.Add((Join-Path $homeDir ".local/bin/agy"))
            if ($roamingApp) { $candidates.Add((Join-Path $roamingApp "npm/agy.cmd")) }
        }
        "workbuddy" {
            if ($localApp) {
                $candidates.Add((Join-Path $localApp "codebuddy/bin/codebuddy.exe"))
                $candidates.Add((Join-Path $localApp "Programs/WorkBuddy/resources/app.asar.unpacked/cli/bin/codebuddy.exe"))
                $candidates.Add((Join-Path $localApp "Programs/WorkBuddy/resources/app.asar.unpacked/cli/bin/codebuddy.cmd"))
            }
            $candidates.Add((Join-Path $homeDir ".local/bin/codebuddy.exe"))
            $candidates.Add((Join-Path $homeDir ".local/bin/codebuddy"))
            if ($roamingApp) { $candidates.Add((Join-Path $roamingApp "npm/codebuddy.cmd")) }
            if ($progFiles) {
                $candidates.Add((Join-Path $progFiles "WorkBuddy/resources/app.asar.unpacked/cli/bin/codebuddy.exe"))
                $candidates.Add((Join-Path $progFiles "WorkBuddy/resources/app.asar.unpacked/cli/bin/codebuddy.cmd"))
            }
            $wbNodeDir = Join-Path $homeDir ".workbuddy/binaries/node/versions"
            if (Test-Path -LiteralPath $wbNodeDir -PathType Container) {
                $wbBins = Get-ChildItem -LiteralPath $wbNodeDir -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending |
                    ForEach-Object {
                        @(
                            (Join-Path $_.FullName "codebuddy.cmd"),
                            (Join-Path $_.FullName "bin/codebuddy")
                        )
                    }
                foreach ($wbBin in $wbBins) {
                    $candidates.Add($wbBin)
                }
            }
            $candidates.Add("/Applications/WorkBuddy.app/Contents/Resources/app.asar.unpacked/cli/bin/codebuddy")
        }
        "claude" {
            $candidates.Add((Join-Path $homeDir ".local/bin/claude.exe"))
            $candidates.Add((Join-Path $homeDir ".local/bin/claude"))
            if ($roamingApp) { $candidates.Add((Join-Path $roamingApp "npm/claude.cmd")) }
        }
    }

    foreach ($cand in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($cand) -and (Test-Path -LiteralPath $cand -PathType Leaf)) {
            return [PSCustomObject]@{
                Available  = $true
                Executable = (Resolve-Path -LiteralPath $cand).Path
                Source     = "known-location"
                EnvVar     = $envVarName
            }
        }
    }

    return [PSCustomObject]@{
        Available  = $false
        Executable = $null
        Source     = "not-found"
        EnvVar     = $envVarName
    }
}

function Get-AgentVersionString {
    param(
        [string]$CanonicalTarget,
        [string]$Executable,
        [int]$TimeoutMs = 5000
    )
    if ([string]::IsNullOrWhiteSpace($Executable)) { return $null }

    $verArgs = switch ($CanonicalTarget) {
        "antigravity" { @("--help") }
        default       { @("--version") }
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $ext = [System.IO.Path]::GetExtension($Executable).ToLowerInvariant()
    if ($ext -in @(".cmd", ".bat")) {
        $psi.FileName = "cmd.exe"
        $psi.ArgumentList.Add("/d")
        $psi.ArgumentList.Add("/c")
        $psi.ArgumentList.Add($Executable)
    } else {
        $psi.FileName = $Executable
    }
    foreach ($a in $verArgs) { $psi.ArgumentList.Add($a) }

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    try {
        [void]$proc.Start()
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        $proc.StandardInput.Close()

        if (-not $proc.WaitForExit($TimeoutMs)) {
            try { $proc.Kill($true) } catch {}
            return "version-check-timeout (${TimeoutMs}ms)"
        }

        $outPart = if ($stdoutTask.Wait(2000)) { $stdoutTask.Result } else { "" }
        $errPart = if ($stderrTask.Wait(2000)) { $stderrTask.Result } else { "" }
        $combined = "$outPart`n$errPart"
        $firstLine = ($combined -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
        return (($firstLine -as [string]) ?? "").Trim()
    } catch {
        return "version-check-failed: $($_.Exception.Message)"
    } finally {
        $proc.Dispose()
    }
}

function Test-IsGitRepo {
    param([string]$Path)
    $null = & git -C $Path rev-parse --is-inside-work-tree 2>$null
    return ($LASTEXITCODE -eq 0)
}

$currentDepth = 0
if (-not [string]::IsNullOrWhiteSpace($env:CROSS_AGENT_DEPTH)) {
    [void][int]::TryParse($env:CROSS_AGENT_DEPTH, [ref]$currentDepth)
}

if ($ListAgents) {
    $targetsToProbe = if ([string]::IsNullOrWhiteSpace($Target) -or $Target.Trim().ToLowerInvariant() -eq "all") {
        @("codex", "antigravity", "workbuddy", "claude")
    } else {
        @(Resolve-AgentName -Name $Target)
    }

    $results = foreach ($t in $targetsToProbe) {
        $info = Find-AgentExecutable -CanonicalTarget $t
        $ver = $null
        if ($CheckVersion -and $info.Available) {
            $ver = Get-AgentVersionString -CanonicalTarget $t -Executable $info.Executable
        }
        [PSCustomObject]@{
            Target     = $t
            Available  = $info.Available
            Executable = $info.Executable
            Source     = $info.Source
            EnvVar     = $info.EnvVar
            Version    = $ver
        }
    }

    $report = [PSCustomObject]@{
        CallerHost = Get-CurrentCallerHost
        Depth      = $currentDepth
        CallChain  = if ([string]::IsNullOrWhiteSpace($env:CROSS_AGENT_CHAIN)) { "none" } else { $env:CROSS_AGENT_CHAIN }
        Agents     = @($results)
    }

    if ($AsJson) {
        $report | ConvertTo-Json -Depth 4
    } else {
        $report
    }
    return
}

$canonicalTarget = Resolve-AgentName -Name $Target
$resolvedWorkingDir = (Resolve-Path -LiteralPath $WorkingDir).Path

if ([string]::IsNullOrWhiteSpace($Prompt) -and [string]::IsNullOrWhiteSpace($PromptFile)) {
    throw "Provide either -Prompt or -PromptFile."
}

$promptText = $Prompt
if (-not [string]::IsNullOrWhiteSpace($PromptFile)) {
    $resolvedPromptFile = (Resolve-Path -LiteralPath $PromptFile).Path
    $fileText = Get-Content -LiteralPath $resolvedPromptFile -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($promptText)) {
        $promptText = $fileText
    } else {
        $promptText = "$promptText`n`n$fileText"
    }
}

$callerHost = if (-not [string]::IsNullOrWhiteSpace($Caller)) {
    $Caller.Trim().ToLowerInvariant()
} else {
    Get-CurrentCallerHost
}

# Recursion, loop, and self-invocation guards
if ($currentDepth -ge $MaxDepth) {
    throw "Cross-agent recursion blocked: current depth ($currentDepth) >= MaxDepth ($MaxDepth). Chain: '$($env:CROSS_AGENT_CHAIN)'."
}

$existingChain = if (-not [string]::IsNullOrWhiteSpace($env:CROSS_AGENT_CHAIN)) {
    $env:CROSS_AGENT_CHAIN
} else {
    $callerHost
}

$chainParts = @($existingChain -split '->' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if (($callerHost -eq $canonicalTarget) -and (-not $AllowSelf)) {
    throw "Self-invocation blocked: caller '$callerHost' equals target '$canonicalTarget'. Prefer native subagents or pass -AllowSelf explicitly."
}

if (($currentDepth -gt 0) -and ($chainParts -contains $canonicalTarget) -and (-not $AllowLoop)) {
    throw "Cross-agent loop blocked: target '$canonicalTarget' already exists in call chain '$existingChain'. Pass -AllowLoop only when intentionally overriding."
}

$nextDepth = $currentDepth + 1
$nextChain = "$existingChain->$canonicalTarget"

$resolvedAgent = Find-AgentExecutable -CanonicalTarget $canonicalTarget
if (-not $resolvedAgent.Available) {
    throw "Target agent '$canonicalTarget' CLI not found (source: $($resolvedAgent.Source)). Install the CLI or set `$env:$($resolvedAgent.EnvVar) to its executable path."
}

$effectivePrompt = if ($RawPrompt) {
    $promptText
} else {
@"
[Cross-Agent Delegation Guardrail]
Caller: $callerHost | Chain: $nextChain | Mode: $Mode
You are invoked as a delegated worker. Complete this task directly in the current workspace.
Do NOT invoke external agents or cross-agent-invoke recursively.
Return concrete evidence (file paths, line numbers, command results, or explicit unknowns).

$promptText
"@
}

$isGitRepo = Test-IsGitRepo -Path $resolvedWorkingDir
$tempOutputFile = $null
$argList = New-Object System.Collections.Generic.List[string]
$useStdinPrompt = $false

switch ($canonicalTarget) {
    "codex" {
        $argList.Add("exec")
        if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
            $argList.Add("resume")
            if (-not [string]::IsNullOrWhiteSpace($Model)) {
                $argList.Add("--model")
                $argList.Add($Model)
            }
            if (-not [string]::IsNullOrWhiteSpace($Effort)) {
                $argList.Add("-c")
                $argList.Add("model_reasoning_effort=`"$Effort`"")
            }
            if ($Worktree) { $argList.Add("--worktree") }
            if (-not $isGitRepo) { $argList.Add("--skip-git-repo-check") }
            if ($OutputFormat -eq "json") { $argList.Add("--json") }
            $tempOutputFile = Join-Path ([System.IO.Path]::GetTempPath()) ("cross-agent-codex-" + [guid]::NewGuid().ToString("N") + ".txt")
            $argList.Add("-o")
            $argList.Add($tempOutputFile)
            foreach ($ea in $ExtraArgs) { $argList.Add($ea) }
            $argList.Add($SessionId)
            $argList.Add("-")
        } else {
            $argList.Add("--cd")
            $argList.Add($resolvedWorkingDir)
            $argList.Add("--sandbox")
            $argList.Add($Mode)
            if (-not $KeepSession) { $argList.Add("--ephemeral") }
            if (-not [string]::IsNullOrWhiteSpace($Model)) {
                $argList.Add("--model")
                $argList.Add($Model)
            }
            if (-not [string]::IsNullOrWhiteSpace($Effort)) {
                $argList.Add("-c")
                $argList.Add("model_reasoning_effort=`"$Effort`"")
            }
            if ($Worktree) { $argList.Add("--worktree") }
            if (-not $isGitRepo) { $argList.Add("--skip-git-repo-check") }
            if ($OutputFormat -eq "json") { $argList.Add("--json") }
            $tempOutputFile = Join-Path ([System.IO.Path]::GetTempPath()) ("cross-agent-codex-" + [guid]::NewGuid().ToString("N") + ".txt")
            $argList.Add("-o")
            $argList.Add($tempOutputFile)
            foreach ($ea in $ExtraArgs) { $argList.Add($ea) }
            $argList.Add("-")
        }
        $useStdinPrompt = $true
    }
    "antigravity" {
        $agyMode = if ($Mode -eq "workspace-write") { "accept-edits" } else { "plan" }
        $argList.Add("--print")
        $argList.Add("--mode")
        $argList.Add($agyMode)
        if ($Mode -eq "read-only") {
            $argList.Add("--sandbox")
        }
        $argList.Add("--output-format")
        $argList.Add($OutputFormat)
        $argList.Add("--print-timeout")
        $argList.Add("${TimeoutSeconds}s")
        $argList.Add("--disable-slash-commands")
        if (-not [string]::IsNullOrWhiteSpace($Model)) {
            $argList.Add("--model")
            $argList.Add($Model)
        }
        if (-not [string]::IsNullOrWhiteSpace($Effort)) {
            $argList.Add("--effort")
            $argList.Add($Effort)
        }
        if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
            $argList.Add("--conversation")
            $argList.Add($SessionId)
        }
        foreach ($ea in $ExtraArgs) { $argList.Add($ea) }
        $argList.Add($effectivePrompt)
        $useStdinPrompt = $false
    }
    "workbuddy" {
        $wbPermMode = if ($Mode -eq "workspace-write") { "acceptEdits" } else { "plan" }
        $argList.Add("-p")
        $argList.Add($effectivePrompt)
        $argList.Add("--permission-mode")
        $argList.Add($wbPermMode)
        $argList.Add("--output-format")
        $argList.Add($OutputFormat)
        if (-not [string]::IsNullOrWhiteSpace($Model)) {
            $argList.Add("--model")
            $argList.Add($Model)
        }
        if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
            $argList.Add("--resume")
            $argList.Add($SessionId)
        }
        foreach ($ea in $ExtraArgs) { $argList.Add($ea) }
        $useStdinPrompt = $false
    }
    "claude" {
        $claudePermMode = if ($Mode -eq "workspace-write") { "acceptEdits" } else { "plan" }
        $argList.Add("-p")
        $argList.Add("--permission-mode")
        $argList.Add($claudePermMode)
        $argList.Add("--output-format")
        $argList.Add($OutputFormat)
        if (-not $KeepSession -and [string]::IsNullOrWhiteSpace($SessionId)) {
            $argList.Add("--no-session-persistence")
        }
        if (-not [string]::IsNullOrWhiteSpace($Model)) {
            $argList.Add("--model")
            $argList.Add($Model)
        }
        if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
            $argList.Add("--resume")
            $argList.Add($SessionId)
        }
        foreach ($ea in $ExtraArgs) { $argList.Add($ea) }
        $useStdinPrompt = $true
    }
}

$displayArgs = @($argList | ForEach-Object {
    if ($_ -eq $effectivePrompt -and $_.Length -gt 120) {
        $_.Substring(0, 120) + "...(truncated)"
    } else {
        $_
    }
})

if ($DryRun) {
    $dryResult = [PSCustomObject]@{
        DryRun          = $true
        Target          = $canonicalTarget
        Caller          = $callerHost
        CallChain       = $nextChain
        NextDepth       = $nextDepth
        Mode            = $Mode
        WorkingDir      = $resolvedWorkingDir
        Executable      = $resolvedAgent.Executable
        Source          = $resolvedAgent.Source
        UseStdinPrompt  = $useStdinPrompt
        Arguments       = $displayArgs
        TimeoutSeconds  = $TimeoutSeconds
    }
    if ($AsJson) {
        $dryResult | ConvertTo-Json -Depth 4
    } else {
        $dryResult
    }
    return
}

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.WorkingDirectory = $resolvedWorkingDir
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

$ext = [System.IO.Path]::GetExtension($resolvedAgent.Executable).ToLowerInvariant()
if ($ext -in @(".cmd", ".bat")) {
    $psi.FileName = "cmd.exe"
    $psi.ArgumentList.Add("/d")
    $psi.ArgumentList.Add("/c")
    $psi.ArgumentList.Add($resolvedAgent.Executable)
    foreach ($a in $argList) { $psi.ArgumentList.Add($a) }
} else {
    $psi.FileName = $resolvedAgent.Executable
    foreach ($a in $argList) { $psi.ArgumentList.Add($a) }
}

$psi.Environment["CROSS_AGENT_DEPTH"] = "$nextDepth"
$psi.Environment["CROSS_AGENT_CHAIN"] = $nextChain
$psi.Environment["CROSS_AGENT_CALLER"] = $callerHost

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$proc = [System.Diagnostics.Process]::new()
$proc.StartInfo = $psi

$timedOut = $false
$stdoutText = ""
$stderrText = ""
$exitCode = -1

try {
    [void]$proc.Start()
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()

    if ($useStdinPrompt) {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        $writer = [System.IO.StreamWriter]::new($proc.StandardInput.BaseStream, $utf8NoBom)
        $writer.Write($effectivePrompt)
        $writer.Flush()
        $writer.Close()
    } else {
        $proc.StandardInput.Close()
    }

    $finished = $proc.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) {
        $timedOut = $true
        try { $proc.Kill($true) } catch {}
    }

    $stdoutText = if ($stdoutTask.Wait(3000)) { $stdoutTask.Result } else { "" }
    $stderrText = if ($stderrTask.Wait(3000)) { $stderrTask.Result } else { "" }
    if (-not $timedOut) {
        $exitCode = $proc.ExitCode
    }
} finally {
    $stopwatch.Stop()
    $proc.Dispose()
}

$finalOutput = $stdoutText.Trim()
if ($tempOutputFile -and (Test-Path -LiteralPath $tempOutputFile -PathType Leaf)) {
    $lastMsg = (Get-Content -LiteralPath $tempOutputFile -Raw -Encoding utf8)
    if (-not [string]::IsNullOrWhiteSpace($lastMsg) -and $OutputFormat -eq "text") {
        $finalOutput = $lastMsg.Trim()
    }
    Remove-Item -LiteralPath $tempOutputFile -Force -ErrorAction SilentlyContinue
}

if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
    $outParent = Split-Path -Path $OutputFile -Parent
    if (-not [string]::IsNullOrWhiteSpace($outParent) -and -not (Test-Path -LiteralPath $outParent)) {
        New-Item -ItemType Directory -Force -Path $outParent | Out-Null
    }
    Set-Content -LiteralPath $OutputFile -Value $finalOutput -Encoding utf8NoBOM
}

$result = [PSCustomObject]@{
    Target          = $canonicalTarget
    Caller          = $callerHost
    CallChain       = $nextChain
    Mode            = $Mode
    Model           = if ([string]::IsNullOrWhiteSpace($Model)) { "default" } else { $Model }
    WorkingDir      = $resolvedWorkingDir
    Executable      = $resolvedAgent.Executable
    ExitCode        = $exitCode
    TimedOut        = $timedOut
    Success         = (-not $timedOut -and $exitCode -eq 0)
    DurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    OutputFile      = if ([string]::IsNullOrWhiteSpace($OutputFile)) { $null } else { $OutputFile }
    Output          = $finalOutput
    Stderr          = $stderrText.Trim()
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 4
} else {
    $result
}

if (-not $result.Success) {
    exit 1
}
