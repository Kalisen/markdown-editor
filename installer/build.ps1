# Publishes a self-contained win-x64 build and compiles the Inno Setup installer.
# Output: artifacts\installer\MarkdownEditor-<version>-setup.exe
# -Version overrides <Version> from Directory.Build.props (the release workflow passes the tag's version).
param(
    [string]$Version,
    [string]$Iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$PublishDir = Join-Path $RepoRoot 'artifacts\publish'
$RuntimeId = 'win-x64'

if (-not (Test-Path $Iscc)) {
    $Iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
}
if (-not (Test-Path $Iscc)) {
    throw "ISCC.exe not found. Install Inno Setup 6 (winget install JRSoftware.InnoSetup) or pass -Iscc <path>."
}

if (Test-Path $PublishDir) { Remove-Item $PublishDir -Recurse -Force }

$PublishArgs = @(
    (Join-Path $RepoRoot 'src\MarkdownEditor.App'), '-c', 'Release', '-r', $RuntimeId, '--self-contained', 'true',
    '-p:PublishReadyToRun=true', '-o', $PublishDir
)
$IsccArgs = @("/DPublishDir=$PublishDir")
if ($Version) {
    $PublishArgs += "-p:Version=$Version"
    $IsccArgs += "/DAppVersion=$Version"
}

dotnet publish @PublishArgs
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)" }

& $Iscc @IsccArgs (Join-Path $PSScriptRoot 'MarkdownEditor.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }
