param(
    [string] $ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string] $CredentialFile = 'C:\dev\Godot\tools\android-signing\ANDROID_SIGNING_CREDENTIALS.txt'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$presetsPath = Join-Path $ProjectRoot 'export_presets.cfg'
$outputPath = Join-Path $ProjectRoot 'builds\clown-smash-rustore-alpha-ads.aab'
$logPath = Join-Path $env:TEMP 'clownsmash-rustore-alpha-export.log'
$godotPath = 'C:\dev\Godot\Godot_console.exe'

function Get-CredentialValue([string[]] $Lines, [string] $Label) {
    $match = $Lines | Where-Object { $_ -match ('^' + [regex]::Escape($Label) + ':\s*(.+)$') } | Select-Object -First 1
    if (-not $match -or $match -notmatch ('^' + [regex]::Escape($Label) + ':\s*(.+)$')) {
        throw "Signing credential field missing: $Label"
    }
    return $Matches[1].Trim()
}

$credentialLines = [IO.File]::ReadAllLines($CredentialFile)
$keyFileName = Get-CredentialValue $credentialLines 'Keystore file'
$keyAlias = Get-CredentialValue $credentialLines 'Alias'
$storePassword = Get-CredentialValue $credentialLines 'Store password'
$keyPassword = Get-CredentialValue $credentialLines 'Key password'
if ($storePassword -cne $keyPassword) { throw 'Godot export preset requires matching store/key passwords.' }
$keyStorePath = (Join-Path (Split-Path -Parent $CredentialFile) $keyFileName).Replace('\', '/')
if (-not (Test-Path -LiteralPath $keyStorePath)) { throw 'Release keystore file is missing.' }

$original = [IO.File]::ReadAllText($presetsPath)
$sectionStart = $original.IndexOf('[preset.7.options]')
if ($sectionStart -lt 0) { throw 'Android - RuStore Alpha Ads preset is missing.' }
$sectionEnd = $original.IndexOf("`n[preset.", $sectionStart)
if ($sectionEnd -lt 0) { $sectionEnd = $original.Length }
$before = $original.Substring(0, $sectionStart)
$section = $original.Substring($sectionStart, $sectionEnd - $sectionStart)
$after = $original.Substring($sectionEnd)
$temporarySettings = @(
    "keystore/release=`"$keyStorePath`""
    "keystore/release_user=`"$keyAlias`""
) -join "`n"
$section = [regex]::Replace($section, '(?m)^keystore/release(_user|_password)?=.*(?:\r?\n|$)', '')
$section = $section.TrimEnd("`r", "`n") + "`n" + $temporarySettings + "`n"

try {
    [IO.File]::WriteAllText($presetsPath, $before + $section + $after, [Text.UTF8Encoding]::new($false))
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $storePassword
    & $godotPath --headless --path $ProjectRoot --export-release 'Android - RuStore Alpha Ads' $outputPath *> $logPath
    $exportExit = $LASTEXITCODE
    if ($exportExit -ne 0 -or -not (Test-Path -LiteralPath $outputPath)) {
        Get-Content -LiteralPath $logPath -Tail 60
        throw "Godot alpha export failed (exit $exportExit)."
    }
    Get-Item -LiteralPath $outputPath | Select-Object FullName, Length, LastWriteTime
}
finally {
    $current = [IO.File]::ReadAllText($presetsPath)
    $cleanStart = $current.IndexOf('[preset.7.options]')
    if ($cleanStart -ge 0) {
        $cleanEnd = $current.IndexOf("`n[preset.", $cleanStart)
        if ($cleanEnd -lt 0) { $cleanEnd = $current.Length }
        $cleanBefore = $current.Substring(0, $cleanStart)
        $cleanSection = $current.Substring($cleanStart, $cleanEnd - $cleanStart)
        $cleanAfter = $current.Substring($cleanEnd)
        $cleanSection = [regex]::Replace($cleanSection, '(?m)^keystore/release(_user|_password)?=.*(?:\r?\n|$)', '')
        [IO.File]::WriteAllText($presetsPath, $cleanBefore + $cleanSection + $cleanAfter, [Text.UTF8Encoding]::new($false))
    }
    $storePassword = $null
    $keyPassword = $null
    $credentialLines = $null
    Remove-Item Env:\GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
}
