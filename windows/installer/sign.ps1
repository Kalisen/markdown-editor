# Authenticode-signs files with a code signing certificate (.pfx) and a timestamp,
# so the signatures stay valid after the certificate expires.
# The .pfx password is read from the CODE_SIGNING_PFX_PASSWORD environment variable, never from the command line.
param(
    [Parameter(Mandatory)][string]$CertificatePath,
    [Parameter(Mandatory)][string[]]$Files
)

$ErrorActionPreference = 'Stop'
$PasswordVariable = 'CODE_SIGNING_PFX_PASSWORD'
$TimestampServer = 'http://timestamp.digicert.com'
$HashAlgorithm = 'SHA256'

$Password = [Environment]::GetEnvironmentVariable($PasswordVariable)
if (-not $Password) { throw "Set $PasswordVariable to the password of $CertificatePath." }

$Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
    (Resolve-Path $CertificatePath).Path, $Password)
if (-not $Certificate.HasPrivateKey) { throw "$CertificatePath has no private key." }

foreach ($File in $Files) {
    $Signature = Set-AuthenticodeSignature -FilePath $File -Certificate $Certificate `
        -TimestampServer $TimestampServer -HashAlgorithm $HashAlgorithm
    # A self-signed certificate is not trusted on the build machine, so 'UnknownError' (untrusted root) is expected;
    # anything else, or a missing signature, means signing failed.
    if (-not $Signature.SignerCertificate -or $Signature.SignerCertificate.Thumbprint -ne $Certificate.Thumbprint) {
        throw "Signing $File failed: $($Signature.Status) $($Signature.StatusMessage)"
    }
    Write-Host "Signed $File ($($Signature.Status))"
}
