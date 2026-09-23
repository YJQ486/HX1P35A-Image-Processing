param()

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$tempDir = Join-Path $scriptRoot '.tmp_sobel_iverilog'
$vvpFile = Join-Path $tempDir 'custom_sobel_4px.vvp'
$defaultVvpFile = Join-Path $tempDir 'custom_sobel_1280x720.vvp'
$evidenceFile = Join-Path $scriptRoot 'sobel_iverilog_evidence.txt'
$iverilog = 'D:\iverilog\bin\iverilog.exe'
$vvp = 'D:\iverilog\bin\vvp.exe'

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$env:TMP = $tempDir
$env:TEMP = $tempDir

$sources = @(
    (Join-Path $root 'rtl\custom\custom_rgb_to_gray.v'),
    (Join-Path $root 'rtl\custom\custom_sobel_4px.v'),
    (Join-Path $scriptRoot 'tb_custom_sobel_4px.v')
)
$rtlSources = @($sources[0], $sources[1])
$defaultCompileCommand = '& "{0}" -g2005 -s custom_sobel_4px -o "{1}" {2}' -f $iverilog, $defaultVvpFile, (($rtlSources | ForEach-Object { '"{0}"' -f $_ }) -join ' ')
$compileCommand = '& "{0}" -g2005 -o "{1}" {2}' -f $iverilog, $vvpFile, (($sources | ForEach-Object { '"{0}"' -f $_ }) -join ' ')
$runCommand = '& "{0}" "{1}"' -f $vvp, $vvpFile
$version = & $iverilog -V 2>&1
$defaultCompileOutput = @()
$compileOutput = @()
$runOutput = @()
$defaultCompileExit = 1
$compileExit = 1
$runExit = 1
$pass = $false

try {
    $defaultCompileOutput = & $iverilog -g2005 -s custom_sobel_4px -o $defaultVvpFile @rtlSources 2>&1
    $defaultCompileExit = $LASTEXITCODE
    if ($defaultCompileExit -eq 0) {
        $compileOutput = & $iverilog -g2005 -o $vvpFile @sources 2>&1
        $compileExit = $LASTEXITCODE
    }
    if (($defaultCompileExit -eq 0) -and ($compileExit -eq 0)) {
        $runOutput = & $vvp $vvpFile 2>&1
        $runExit = $LASTEXITCODE
    }
    $pass = ($defaultCompileExit -eq 0) -and ($compileExit -eq 0) -and ($runExit -eq 0) -and (($runOutput -join "`n") -match 'PASS: sobel checks')
} finally {
    $evidence = @(
        'Simulator: Icarus Verilog',
        'Version:', $version,
        'Default 1280x720 RTL compile command:', $defaultCompileCommand,
        'Default 1280x720 RTL compile exit status: ' + $defaultCompileExit,
        'Default 1280x720 RTL compile output:', $defaultCompileOutput,
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
