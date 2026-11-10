# Creates the self-signed code signing certificate used to sign Markdown Editor releases.
# Output (keep the .pfx private, never commit it):
#   <OutputDirectory>\markdown-editor-code-signing.pfx  certificate + private key, password protected
#   <OutputDirectory>\markdown-editor-code-signing.cer  public certificate, for users who choose to trust it
# Then store the .pfx in the repository secrets (see README > Code signing).
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [int]$ValidityYears = 5
)

$ErrorActionPreference = 'Stop'
# Must match AppPublisher in installer\MarkdownEditor.iss: it is the publisher name Windows shows.
$Subject = 'CN=Kalisen'
$FileBaseName = 'markdown-editor-code-signing'

New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$PfxPath = Join-Path $OutputDirectory "$FileBaseName.pfx"
$CerPath = Join-Path $OutputDirectory "$FileBaseName.cer"
if ((Test-Path $PfxPath) -or (Test-Path $CerPath)) {
    throw "$PfxPath or $CerPath already exists; move it away or pick another -OutputDirectory."
}

$Password = Read-Host -AsSecureString 'Password for the .pfx'

$Certificate = New-SelfSignedCertificate -Type CodeSigningCert -Subject $Subject `
    -KeyAlgorithm RSA -KeyLength 3072 -HashAlgorithm SHA256 -KeyExportPolicy Exportable `
    -NotAfter (Get-Date).AddYears($ValidityYears) -CertStoreLocation Cert:\CurrentUser\My
try {
    Export-PfxCertificate -Cert $Certificate -FilePath $PfxPath -Password $Password | Out-Null
    Export-Certificate -Cert $Certificate -FilePath $CerPath | Out-Null
}
finally {
    # The .pfx is the only copy kept; don't leave the private key in the certificate store.
    Remove-Item "Cert:\CurrentUser\My\$($Certificate.Thumbprint)"
}

Write-Host "Created $PfxPath and $CerPath (thumbprint $($Certificate.Thumbprint), expires $($Certificate.NotAfter:d))."
Write-Host 'Store it in the repository secrets:'
Write-Host "  [Convert]::ToBase64String([IO.File]::ReadAllBytes('$PfxPath')) | gh secret set CODE_SIGNING_PFX_BASE64"
Write-Host '  gh secret set CODE_SIGNING_PFX_PASSWORD'
