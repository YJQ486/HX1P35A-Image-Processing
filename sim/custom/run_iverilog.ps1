param()

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$tempDir = Join-Path $scriptRoot '.tmp_iverilog'
$vvpFile = Join-Path $tempDir 'custom_axis96_mode_adapter.vvp'
$evidenceFile = Join-Path $scriptRoot 'iverilog_evidence.txt'
$iverilog = 'D:\iverilog\bin\iverilog.exe'
$vvp = 'D:\iverilog\bin\vvp.exe'

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$env:TMP = $tempDir
$env:TEMP = $tempDir

$sources = @(
    (Join-Path $root 'rtl\custom\custom_rgb_passthrough.v'),
    (Join-Path $root 'rtl\custom\custom_rgb_to_gray.v'),
    (Join-Path $root 'rtl\custom\custom_gray_threshold.v'),
    (Join-Path $root 'rtl\custom\custom_axis96_mode_adapter.v'),
    (Join-Path $scriptRoot 'tb_custom_axis96_mode_adapter.v')
)
$compileCommand = '& "{0}" -g2005 -o "{1}" {2}' -f $iverilog, $vvpFile, (($sources | ForEach-Object { '"{0}"' -f $_ }) -join ' ')
$runCommand = '& "{0}" "{1}"' -f $vvp, $vvpFile
$version = & $iverilog -V 2>&1
$compileOutput = @()
$runOutput = @()
$compileExit = 1
$runExit = 1

try {
    $compileOutput = & $iverilog -g2005 -o $vvpFile @sources 2>&1
    $compileExit = $LASTEXITCODE
    if ($compileExit -eq 0) {
        $runOutput = & $vvp $vvpFile 2>&1
        $runExit = $LASTEXITCODE
    }
    $pass = ($compileExit -eq 0) -and ($runExit -eq 0) -and (($runOutput -join "`n") -match 'PASS: adapter checks')
} finally {
    $evidence = @(
        'Simulator: Icarus Verilog',
        'Version:', $version,
        'Compile command:', $compileCommand,
        'Compile exit status: ' + $compileExit,
        'Compile output:', $compileOutput,
        'Run command:', $runCommand,
        'Run exit status: ' + $runExit,
        'Run output:', $runOutput,
        'PASS: ' + $pass
    )
    Set-Content -LiteralPath $evidenceFile -Value $evidence -Encoding utf8
    if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
}

if (-not $pass) { exit 1 }
exit 0
