param([Parameter(Mandatory)][string]$Preset, [switch]$Release, [switch]$Plan)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. 'C:\dev\Godot\tools\godot-build-policy.ps1'
if ($Preset -eq 'Android - RuStore Alpha Ads' -and $Release) {
    & (Join-Path $PSScriptRoot 'export-rustore-alpha.ps1') -ProjectRoot $root -Plan:$Plan
    return
}
$platformBuild = $null
if (-not $Plan -and $Preset -match '(?i)\b(vk|ok|yandex)\b') {
    $platformBuild = Get-GodotBuildPlan -Project $root -Preset $Preset -Release:$Release
}
if ($Plan) {
    Invoke-GodotExport -Project $root -Preset $Preset -Release:$Release -Plan
    return
}

$useTentBackdrop = $platformBuild -and $platformBuild.NativePlatform -eq 'Web' -and $platformBuild.Platform -in @('vk', 'ok', 'yandex')
$enableReleaseAnalytics = $Release -and $platformBuild -and $platformBuild.Platform -in @('vk', 'ok')
if (-not $useTentBackdrop -and -not $enableReleaseAnalytics) {
    Invoke-GodotExport -Project $root -Preset $Preset -Release:$Release
    return
}

$shellPath = Join-Path $root 'web/portrait_shell.html'
$originalShell = if ($useTentBackdrop) { [IO.File]::ReadAllBytes($shellPath) } else { $null }
$analyticsPath = Join-Path $root 'config/game_analytics.cfg'
$originalAnalytics = if ($enableReleaseAnalytics) { [IO.File]::ReadAllBytes($analyticsPath) } else { $null }
try {
    if ($useTentBackdrop) {
        $backdropPath = Join-Path $root 'tools/page-assets/circus-tent-backdrop.jpg'
        $backdropData = [Convert]::ToBase64String([IO.File]::ReadAllBytes($backdropPath))
        $shell = [Text.Encoding]::UTF8.GetString($originalShell)
        $placeholder = '__CLOWNSMASH_TENT_BACKDROP__'
        if (($shell.Split($placeholder).Count - 1) -ne 1) { throw 'Expected exactly one tent-backdrop placeholder in the HTML shell.' }
        $shell = $shell.Replace($placeholder, "data:image/jpeg;base64,$backdropData")
        [IO.File]::WriteAllText($shellPath, $shell, [Text.UTF8Encoding]::new($false))
    }
    if ($enableReleaseAnalytics) {
        $analytics = [Text.Encoding]::UTF8.GetString($originalAnalytics)
        $analytics = [regex]::Replace($analytics, '(?m)^mode=.*$', 'mode="production"')
        $analytics = [regex]::Replace($analytics, '(?m)^contract_verified=.*$', 'contract_verified=true')
        $analytics = [regex]::Replace($analytics, '(?m)^platform=.*$', "platform=`"$($platformBuild.Platform)`"")
        $analytics = [regex]::Replace($analytics, '(?m)^app_version=.*$', "app_version=`"$($platformBuild.Version)`"")
        [IO.File]::WriteAllText($analyticsPath, $analytics, [Text.UTF8Encoding]::new($false))
    }
    Invoke-GodotExport -Project $root -Preset $Preset -Release:$Release
} finally {
    if ($null -ne $originalAnalytics) { [IO.File]::WriteAllBytes($analyticsPath, $originalAnalytics) }
    if ($null -ne $originalShell) { [IO.File]::WriteAllBytes($shellPath, $originalShell) }
}
