# Publishes a self-contained win-x64 build and compiles the Inno Setup installer.
# Output: artifacts\installer\MarkdownEditor-<version>-setup.exe
param(
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

dotnet publish (Join-Path $RepoRoot 'src\MarkdownEditor.App') -c Release -r $RuntimeId --self-contained true `
    -p:PublishReadyToRun=true -o $PublishDir
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)" }

& $Iscc "/DPublishDir=$PublishDir" (Join-Path $PSScriptRoot 'MarkdownEditor.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }
