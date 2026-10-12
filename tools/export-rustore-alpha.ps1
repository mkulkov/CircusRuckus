param(
    [string] $ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string] $CredentialFile = 'C:\dev\Godot\tools\android-signing\ANDROID_SIGNING_CREDENTIALS.txt',
    [switch] $Plan
)
$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
. 'C:\dev\Godot\tools\godot-build-policy.ps1'
if ([IO.Path]::GetFullPath($CredentialFile) -ine 'C:\dev\Godot\tools\android-signing\ANDROID_SIGNING_CREDENTIALS.txt') {
    throw 'Android releases must use the shared signing parameters from C:\dev\Godot\tools\android-signing.'
}
$presetName = 'Android - RuStore Alpha Ads'
if ($Plan) {
    Get-GodotBuildPlan -Project $ProjectRoot -Preset $presetName -Release |
        Select-Object Preset,Platform,Release,Version,VersionCode,PackageIdentifier,OutputPath,ArchivePath
    return
}
$context = Start-GodotBuild -Project $ProjectRoot -Preset $presetName -Release
try {
    $logPath = Join-Path $context.MetadataDirectory 'export.log'
    & 'C:\dev\Godot\Godot_console.exe' --headless --path $ProjectRoot --export-release $presetName $context.OutputPath *> $logPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $context.OutputPath)) {
        Get-Content -LiteralPath $logPath -Tail 60
        throw "Godot alpha export failed (exit $LASTEXITCODE)."
    }
    Complete-GodotBuild -Context $context
    Get-Item -LiteralPath $context.OutputPath | Select-Object FullName,Length,LastWriteTime
} finally { Undo-GodotBuild -Context $context }