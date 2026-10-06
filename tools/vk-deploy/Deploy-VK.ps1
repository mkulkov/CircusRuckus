param(
    [ValidateSet('Dev', 'Prod', 'Both')]
    [string]$Target = 'Dev',

    [string]$BuildDirectory = (Join-Path $PSScriptRoot '..\..\builds\vk'),

    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
$appId = '54768735'
$expectedFiles = @(
    'index.apple-touch-icon.png'
    'index.audio.position.worklet.js'
    'index.audio.worklet.js'
    'index.html'
    'index.icon.png'
    'index.js'
    'index.pck'
    'index.png'
    'index.wasm'
)
$deployDirectory = $PSScriptRoot
$configPath = Join-Path $deployDirectory 'vk-hosting-config.json'
$resolvedBuildDirectory = (Resolve-Path -LiteralPath $BuildDirectory).Path

if (-not (Get-Command node -ErrorAction SilentlyContinue) -or
    -not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw 'Node.js and npm are required. Install the current Node.js LTS release, then rerun this script.'
}

$actualFiles = @(Get-ChildItem -LiteralPath $resolvedBuildDirectory -File | ForEach-Object Name | Sort-Object)
$expectedSorted = @($expectedFiles | Sort-Object)
if (Compare-Object -ReferenceObject $expectedSorted -DifferenceObject $actualFiles) {
    throw "The build directory must contain exactly the nine VK runtime files: $resolvedBuildDirectory"
}

Write-Host "Build: $resolvedBuildDirectory"
Get-ChildItem -LiteralPath $resolvedBuildDirectory -File |
    Get-FileHash -Algorithm SHA256 |
    Sort-Object Path |
    ForEach-Object { Write-Host ("  {0}  {1}" -f $_.Hash, (Split-Path $_.Path -Leaf)) }
Write-Host "VK app: $appId"
Write-Host "Target: $Target"
Write-Host 'Runtime files: 9 (validated)'

if ($ValidateOnly) {
    Write-Host 'Validation complete; no upload was started.'
    exit 0
}

$confirmation = switch ($Target) {
    'Dev'  { 'DEPLOY DEV' }
    'Prod' { 'DEPLOY PROD' }
    'Both' { 'DEPLOY BOTH' }
}
Write-Host "This will upload the selected build to VK app $appId and update: $Target."
Write-Host "Type '$confirmation' to continue, or anything else to cancel."
$answer = Read-Host 'Confirm deployment'
if ($answer -ine $confirmation) {
    Write-Host 'Cancelled; nothing was uploaded.'
    exit 0
}

$nodeModules = Join-Path $deployDirectory 'node_modules'
if (-not (Test-Path -LiteralPath $nodeModules)) {
    Push-Location $deployDirectory
    try {
        & npm ci --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "npm ci failed with exit code $LASTEXITCODE." }
    }
    finally {
        Pop-Location
    }
}

$originalConfigBytes = [System.IO.File]::ReadAllBytes($configPath)
$originalConfig = [System.Text.Encoding]::UTF8.GetString($originalConfigBytes)
try {
    $config = $originalConfig | ConvertFrom-Json
    $config.app_id = $appId
    Push-Location $deployDirectory
    try {
        $config.static_path = Resolve-Path -LiteralPath $resolvedBuildDirectory -Relative
    }
    finally {
        Pop-Location
    }
    $config.noprompt = $true
    $config.update_dev = $Target -in @('Dev', 'Both')
    $config.update_prod = $Target -in @('Prod', 'Both')
    $configJson = $config | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($configPath, $configJson, [System.Text.UTF8Encoding]::new($false))

    Push-Location $deployDirectory
    try {
        & npm run deploy
        if ($LASTEXITCODE -ne 0) { throw "VK deploy CLI failed with exit code $LASTEXITCODE." }
    }
    finally {
        Pop-Location
    }
}
finally {
    [System.IO.File]::WriteAllBytes($configPath, $originalConfigBytes)
}

Write-Host 'VK deploy command completed successfully.'
