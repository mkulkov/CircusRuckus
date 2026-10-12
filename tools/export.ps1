param([Parameter(Mandatory)][string]$Preset, [switch]$Release, [switch]$Plan)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. 'C:\dev\Godot\tools\godot-build-policy.ps1'
if ($Preset -eq 'Android - RuStore Alpha Ads' -and $Release) {
    & (Join-Path $PSScriptRoot 'export-rustore-alpha.ps1') -ProjectRoot $root -Plan:$Plan
    return
}
if ($Release -and $Preset -match '(?i)\b(vk|ok)\b') {
    if ($Plan) {
        Invoke-GodotExport -Project $root -Preset $Preset -Release -Plan
        return
    }
    $platform = if ($Preset -match '(?i)\bok\b') { 'ok' } else { 'vk' }
    $buildPlan = Get-GodotBuildPlan -Project $root -Preset $Preset -Release
    $analyticsPath = Join-Path $root 'config/game_analytics.cfg'
    $originalAnalytics = [IO.File]::ReadAllBytes($analyticsPath)
    try {
        $analytics = [Text.Encoding]::UTF8.GetString($originalAnalytics)
        $analytics = [regex]::Replace($analytics, '(?m)^mode=.*$', 'mode="production"')
        $analytics = [regex]::Replace($analytics, '(?m)^contract_verified=.*$', 'contract_verified=true')
        $analytics = [regex]::Replace($analytics, '(?m)^platform=.*$', "platform=`"$platform`"")
        $analytics = [regex]::Replace($analytics, '(?m)^app_version=.*$', "app_version=`"$($buildPlan.Version)`"")
        [IO.File]::WriteAllText($analyticsPath, $analytics, [Text.UTF8Encoding]::new($false))
        Invoke-GodotExport -Project $root -Preset $Preset -Release
    } finally {
        [IO.File]::WriteAllBytes($analyticsPath, $originalAnalytics)
    }
    return
}
Invoke-GodotExport -Project $root -Preset $Preset -Release:$Release -Plan:$Plan
