# Build + package the Windows PC client. Always use this script; do not run
# cmake by hand: an unquoted -DCMAKE_PREFIX_PATH=$var in PowerShell poisons the
# CMake cache with a literal "$var" (this script self-heals by deleting
# build-msvc\ on every run). Requires PowerShell FullLanguage mode; under a
# Constrained Language Mode sandbox it fails with a misleading dot-source error.
# Each step's output is written to build-msvc\*.log and the log tail is printed
# on failure.
[CmdletBinding()]
param(
    [string]$QtDir = "C:\Qt\6.11.0\msvc2022_64",
    [string]$BuildDir = "",
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$Config = "Release",
    [string]$Generator = "Visual Studio 17 2022",
    [string]$Architecture = "x64",
    [ValidateRange(1, 86400)][int]$DeployTimeoutSeconds = 120,
    [ValidateRange(1, 86400)][int]$CleanTimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"

$ClientDir = $PSScriptRoot
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $ClientDir "..")).Path
if ([string]::IsNullOrWhiteSpace($BuildDir)) {
    # Keep the generated tree OUTSIDE the Dropbox-synced repo: sync file locks
    # make in-tree cmake configure hang before CompilerId and slow every build.
    $BuildDir = Join-Path ([System.IO.Path]::GetTempPath()) "netchesszx-msvc-dist"
}
$DistDir = Join-Path $ProjectRoot "release\shatranj-client"
$PackagedExe = Join-Path $DistDir "shatranj-client.exe"
$WinDeployQtExe = Join-Path $QtDir "bin\windeployqt.exe"

function Resolve-Tool {
    param([Parameter(Mandatory = $true)][string]$Name)

    return (Get-Command $Name -ErrorAction Stop).Source
}

function Test-IsWithinRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $pathNorm = $Path.TrimEnd('\')
    $rootNorm = $Root.TrimEnd('\')
    if ($pathNorm.Equals($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    return $pathNorm.StartsWith($rootNorm + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Remove-GeneratedTree {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [int]$TimeoutSeconds = $CleanTimeoutSeconds
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    if (-not (Test-IsWithinRoot -Path $resolvedPath -Root $resolvedRoot)) {
        throw "Refusing to remove outside generated tree: $resolvedPath"
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = $null
    do {
        try {
            Remove-Item -LiteralPath $resolvedPath -Recurse -Force -ErrorAction Stop
            return
        } catch {
            $lastError = $_
            Start-Sleep -Milliseconds 300
        }
    } while ((Get-Date) -lt $deadline)

    throw "Unable to clean generated output after ${TimeoutSeconds}s: $resolvedPath. Close running Shatranj client or locked Qt DLLs and retry. Last error: $($lastError.Exception.Message)"
}

function Invoke-ProcessChecked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$LogPath = ""
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # Idle MSBuild worker nodes outlive the build and keep the redirected pipes
    # (and object files) open; disable reuse so the output streams close on exit.
    $psi.EnvironmentVariables["MSBUILDDISABLENODEREUSE"] = "1"
    foreach ($arg in $Arguments) {
        [void]$psi.ArgumentList.Add($arg)
    }

    Write-Host "[$Name] started (timeout ${TimeoutSeconds}s)..."
    $process = [System.Diagnostics.Process]::Start($psi)
    try {
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        # Heartbeat: agent harnesses kill silent processes after ~120s, and the
        # child output is captured to logs, so emit progress lines while waiting.
        $elapsed = 0
        $exited = $false
        while (-not $exited -and $elapsed -lt $TimeoutSeconds) {
            $exited = $process.WaitForExit(30000)
            if (-not $exited) {
                $elapsed += 30
                Write-Host "[$Name] still running (${elapsed}s elapsed)..."
            }
        }
        if (-not $exited) {
            # Kill the whole tree: a plain Stop-Process orphans MSBuild/cl.exe
            # children, which keep .obj/.pdb locked and break the next run.
            & taskkill /PID $process.Id /T /F 2>$null | Out-Null
            throw "$Name timed out after ${TimeoutSeconds}s. Close running Shatranj client or locked Qt DLLs and retry."
        }
        $output = ""
        if ([System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask), 15000)) {
            $output = $stdoutTask.Result + $stderrTask.Result
        } else {
            $output = "(output unavailable: stream still held by a child process)"
        }
        if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LogPath) | Out-Null
            Set-Content -LiteralPath $LogPath -Value $output
        }
        if ($process.ExitCode -ne 0) {
            $tail = ($output -split "`r?`n" | Where-Object { $_ -ne "" } | Select-Object -Last 40) -join "`n"
            throw "$Name failed with exit code $($process.ExitCode). Last output:`n$tail"
        }
        Write-Host "[$Name] done."
    } finally {
        $process.Dispose()
    }
}

function Copy-SelectedChildren {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string[]]$Names
    )

    if (-not (Test-Path -LiteralPath $Source)) { return }
    Remove-GeneratedTree -Path $Destination -Root $DistDir
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($name in $Names) {
        Copy-Item -LiteralPath (Join-Path $Source $name) -Destination $Destination -Force -Recurse
    }
}

function Copy-Contents {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) { return }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Copy-Item -Path (Join-Path $Source "*") -Destination $Destination -Force -Recurse
}

function Remove-UnlistedDeploymentFiles {
    param([Parameter(Mandatory = $true)][string]$Path)

    $keepRootFiles = @(
        "shatranj-client.exe", "Qt6Core.dll", "Qt6Gui.dll", "Qt6Network.dll",
        "Qt6Svg.dll", "Qt6Widgets.dll", "icuuc.dll", "concrt140.dll",
        "msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll",
        "msvcp140_atomic_wait.dll", "msvcp140_codecvt_ids.dll",
        "vccorlib140.dll", "vcruntime140.dll", "vcruntime140_1.dll",
        "vcruntime140_threads.dll"
    )
    $keepDirs = @("assets", "imageformats", "platforms")
    foreach ($item in Get-ChildItem -LiteralPath $Path -Force) {
        if ($item.PSIsContainer) {
            if ($keepDirs -notcontains $item.Name) {
                Remove-GeneratedTree -Path $item.FullName -Root $Path
            }
        } elseif ($keepRootFiles -notcontains $item.Name) {
            Remove-GeneratedTree -Path $item.FullName -Root $Path
        }
    }

    $pluginKeep = @{ imageformats = @("qjpeg.dll"); platforms = @("qwindows.dll") }
    foreach ($dirName in $pluginKeep.Keys) {
        $dir = Join-Path $Path $dirName
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($item in Get-ChildItem -LiteralPath $dir -Force) {
            if ($item.PSIsContainer) {
                Remove-GeneratedTree -Path $item.FullName -Root $dir
            } elseif ($pluginKeep[$dirName] -notcontains $item.Name) {
                Remove-GeneratedTree -Path $item.FullName -Root $dir
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $QtDir)) { throw "Qt directory not found: $QtDir" }
if (-not (Test-Path -LiteralPath $WinDeployQtExe)) { throw "Qt deploy tool not found: $WinDeployQtExe" }
$cmake = Resolve-Tool "cmake"

Remove-GeneratedTree -Path $BuildDir -Root (Split-Path -Parent $BuildDir)
Remove-GeneratedTree -Path $DistDir -Root $ProjectRoot
Remove-GeneratedTree -Path (Join-Path $ProjectRoot "release\netchesszx-client") -Root $ProjectRoot
Remove-GeneratedTree -Path (Join-Path $ProjectRoot "release\shatranj") -Root $ProjectRoot
Remove-GeneratedTree -Path (Join-Path $ClientDir "dist\shatranj") -Root $ClientDir
Remove-GeneratedTree -Path (Join-Path $ClientDir "dist\netchesszx-client") -Root $ClientDir
Remove-GeneratedTree -Path (Join-Path $ClientDir "dist\zxchess-client") -Root $ClientDir

$configureArgs = @(
    "-S", $ClientDir,
    "-B", $BuildDir,
    "-G", $Generator,
    "-DCMAKE_PREFIX_PATH=$QtDir"
)
if (-not [string]::IsNullOrWhiteSpace($Architecture)) {
    $configureArgs += @("-A", $Architecture)
}

Invoke-ProcessChecked -FilePath $cmake -Arguments $configureArgs -TimeoutSeconds 120 -Name "cmake configure" -LogPath (Join-Path $BuildDir "configure.log")
Invoke-ProcessChecked -FilePath $cmake -Arguments @("--build", $BuildDir, "--config", $Config) -TimeoutSeconds 300 -Name "cmake build" -LogPath (Join-Path $BuildDir "build.log")

$exe = @(
    (Join-Path $BuildDir "$Config\shatranj-client.exe"),
    (Join-Path $BuildDir "shatranj-client.exe")
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $exe) { throw "Built executable not found under $BuildDir" }

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
Copy-Item -LiteralPath $exe -Destination $PackagedExe -Force
$deployMode = if ($Config -eq "Debug") { "--debug" } else { "--release" }
Invoke-ProcessChecked `
    -FilePath $WinDeployQtExe `
    -Arguments @($deployMode, "--compiler-runtime", "--no-translations", "--no-system-d3d-compiler", "--no-opengl-sw", $PackagedExe) `
    -TimeoutSeconds $DeployTimeoutSeconds `
    -Name "windeployqt" `
    -LogPath (Join-Path $BuildDir "windeployqt.log")

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path -LiteralPath $vswhere)) { throw "vswhere not found: $vswhere" }
$vsInstall = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
$crtDir = Get-ChildItem -LiteralPath (Join-Path $vsInstall "VC\Redist\MSVC") -Directory |
    Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName "x64\Microsoft.VC143.CRT" } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not $crtDir) { throw "MSVC x64 runtime directory not found" }
Copy-Item -LiteralPath (Get-ChildItem -LiteralPath $crtDir -Filter "*.dll").FullName `
    -Destination $DistDir -Force

Copy-SelectedChildren `
    -Source (Join-Path $ProjectRoot "assets\pc-client\piece_sets") `
    -Destination (Join-Path $DistDir "assets\pc-client\piece_sets") `
    -Names @("california", "gioco", "kiwen-suwi", "merida", "mpchess")
Copy-SelectedChildren `
    -Source (Join-Path $ProjectRoot "assets\pc-client\boards") `
    -Destination (Join-Path $DistDir "assets\pc-client\boards") `
    -Names @("blue.png", "blue3.jpg", "green.png", "purple-diag.png", "wood4.jpg")
Copy-Contents `
    -Source (Join-Path $ProjectRoot "assets\pc-client\about") `
    -Destination (Join-Path $DistDir "assets\pc-client\about")
Copy-Contents `
    -Source (Join-Path $ProjectRoot "assets\pc-client\pieces") `
    -Destination (Join-Path $DistDir "assets\pc-client\pieces")

Remove-UnlistedDeploymentFiles -Path $DistDir

Write-Host "Built: $exe"
Write-Host "Packaged: $PackagedExe"
