# Publishes a self-contained win-x64 build and compiles the Inno Setup installer.
# Output: artifacts\installer\MarkdownEditor-<version>-setup.exe
# -Version overrides <Version> from Directory.Build.props (the release workflow passes the tag's version).
# -CertificatePath (a .pfx, password in CODE_SIGNING_PFX_PASSWORD) signs the app's own binaries before packaging
# and the installer after, and writes the public certificate next to the installer
# (artifacts\installer\MarkdownEditor-code-signing.cer).
param(
    [string]$Version,
    [string]$CertificatePath,
    [string]$Iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$PublishDir = Join-Path $RepoRoot 'artifacts\publish'
$InstallerDir = Join-Path $RepoRoot 'artifacts\installer'
$RuntimeId = 'win-x64'
# The app's own binaries (exe, core and plugin assemblies); third-party DLLs are left as shipped.
$OwnBinaryPatterns = @('MarkdownEditor.exe', 'MarkdownEditor*.dll')
$PublicCertificateName = 'MarkdownEditor-code-signing.cer'
$SignScript = Join-Path $PSScriptRoot 'sign.ps1'

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

if ($CertificatePath) {
    $OwnBinaries = Get-ChildItem $PublishDir -Recurse -File -Include $OwnBinaryPatterns
    & $SignScript -CertificatePath $CertificatePath -Files $OwnBinaries.FullName
}

if (Test-Path $InstallerDir) { Remove-Item $InstallerDir -Recurse -Force }
& $Iscc @IsccArgs (Join-Path $PSScriptRoot 'MarkdownEditor.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }

if ($CertificatePath) {
    $Installer = Get-ChildItem $InstallerDir -Filter *.exe
    & $SignScript -CertificatePath $CertificatePath -Files $Installer.FullName
    $PublicCertificate = (Get-AuthenticodeSignature $Installer.FullName).SignerCertificate
    [IO.File]::WriteAllBytes((Join-Path $InstallerDir $PublicCertificateName),
        $PublicCertificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
}
