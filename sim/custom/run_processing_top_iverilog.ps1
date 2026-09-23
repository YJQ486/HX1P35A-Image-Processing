param()

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$tempDir = Join-Path $scriptRoot '.tmp_processing_top_iverilog'
$evidenceFile = Join-Path $scriptRoot 'processing_top_iverilog_evidence.txt'
$iverilog = 'D:\iverilog\bin\iverilog.exe'
$vvp = 'D:\iverilog\bin\vvp.exe'
if (-not (Test-Path -LiteralPath $iverilog -PathType Leaf)) { throw "Icarus compiler not found: $iverilog" }
if (-not (Test-Path -LiteralPath $vvp -PathType Leaf)) { throw "Icarus runner not found: $vvp" }
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$env:TMP = $tempDir
$env:TEMP = $tempDir

$sources = @(
    (Join-Path $root 'rtl\custom\custom_rgb_to_gray.v'),
    (Join-Path $root 'rtl\custom\custom_gray_threshold.v'),
    (Join-Path $root 'rtl\custom\custom_sobel_4px.v'),
    (Join-Path $root 'rtl\custom\custom_processing_top.v'),
    (Join-Path $scriptRoot 'tb_custom_processing_top.v')
)
$version = & $iverilog -V 2>&1
$evidence = @('Simulator: Icarus Verilog', 'Version:', $version)
$passed = $true
foreach ($configuration in @(
    @{ Name = 'default_1280x720'; Width = 1280; Height = 720 },
    @{ Name = 'small_16x6'; Width = 16; Height = 6 }
)) {
    $vvpFile = Join-Path $tempDir ($configuration.Name + '.vvp')
    $compileArgs = @('-g2005', '-Wall', '-s', 'tb_custom_processing_top',
                     ('-Ptb_custom_processing_top.IMG_WIDTH=' + $configuration.Width),
                     ('-Ptb_custom_processing_top.IMG_HEIGHT=' + $configuration.Height),
                     '-o', $vvpFile) + $sources
    $quotedArgs = ($compileArgs | ForEach-Object { '"{0}"' -f $_ }) -join ' '
    $evidence += @('Configuration: ' + $configuration.Name,
                   'Compile command: & "' + $iverilog + '" ' + $quotedArgs)
    $compileOutput = & $iverilog @compileArgs 2>&1
    $compileExit = $LASTEXITCODE
    $evidence += @('Compile exit status: ' + $compileExit, 'Compile output:')
    $evidence += $compileOutput
    $runExit = 1
    $runOutput = @()
    if ($compileExit -eq 0) {
        $evidence += 'Run command: & "' + $vvp + '" "' + $vvpFile + '"'
        $runOutput = & $vvp $vvpFile 2>&1
        $runExit = $LASTEXITCODE
    }
    $casePassed = ($compileExit -eq 0) -and ($runExit -eq 0) -and
                  (($runOutput -join "`n") -match 'PASS: processing top') -and
                  (($runOutput -join "`n") -match 'errors=0')
    $evidence += @('Run exit status: ' + $runExit, 'Run output:')
    $evidence += $runOutput
    $evidence += 'PASS: ' + $casePassed
    if (-not $casePassed) { $passed = $false }
}
Set-Content -LiteralPath $evidenceFile -Value $evidence -Encoding utf8
if (-not $passed) { exit 1 }
exit 0
