# Project Polaris

# RB-010 - ROOTCA01 Recovery & Implementation

## Formal Closeout and Publication Record

| Control field | Value |
|---|---|
| Document ID | RB-010 |
| Version | 1.0 |
| Publication date | 2026-08-13 |
| Status | Implementation Complete / Frozen |
| Document class | Recovery & Implementation Runbook Closeout |
| Project | Homelab Project Polaris |
| Validation scope | Final PKI acceptance validation |
| Next milestone | Complete remaining Active Directory structure |

> **Completion decision:** RB-010 implementation is complete. The Project Polaris two-tier PKI is operational and validated: `Polaris Root CA` is the trust anchor, `Polaris Issuing CA` on `CA01.ad.polaris` is the Enterprise Subordinate CA, and `ADMIN-WS.ad.polaris` successfully enrolled a machine certificate that chains to the Project Polaris Root CA.

## 1. Publication Scope

This controlled record formally closes RB-010 and publishes the final acceptance procedure and evidence for Step 5.8.

Steps 1 through 5.7 were completed, validated, and frozen during implementation. This publication does not redesign, repeat, or reconstruct those frozen procedures. Step 5.8 begins from the established state in which:

- Root CA public artifacts had already been created on ROOTCA01.
- The required artifacts had already been transported through Admin-WS to CA01 and DC01.
- CA01 had already been configured as the domain-integrated issuing CA.
- CA01 had already issued a machine certificate to Admin-WS.

The previously proposed interpretation of Step 5.8 as another artifact-transport operation was rejected because the transport and CA-establishment workflow was already complete. Step 5.8 is therefore published as **Final PKI Acceptance Validation**.

## 2. Authoritative Implemented State

| Component | Implemented role | Accepted state |
|---|---|---|
| ROOTCA01 | Standalone/offline Root CA host | Root of trust established as `Polaris Root CA` |
| CA01 | Domain-integrated issuing CA host | `Polaris Issuing CA`; Enterprise Subordinate CA; service operational |
| DC01 | Active Directory and PKI integration point | Supports the domain-integrated CA and trust distribution |
| ADMIN-WS | Administrative enrollment endpoint | Holds a valid machine certificate issued by `Polaris Issuing CA` |

### 2.1 Accepted Admin-WS Certificate

| Property | Accepted value |
|---|---|
| Store | `LocalMachine\My` |
| Subject | `CN=ADMIN-WS.ad.polaris` |
| Issuer | `CN=Polaris Issuing CA, DC=ad, DC=polaris` |
| Thumbprint | `9033E3E0243F9EA1E17965D82E5EA11BE941DA53` |
| Valid from | 2026-08-13 12:18:40 |
| Valid through | 2027-08-13 12:18:40 |
| Private key | Present |
| Enhanced key usage | Client Authentication; Server Authentication |
| Certificate template | Machine |
| CA request ID | `0x7` |
| CA disposition | `20 - Issued` |

The serial number displayed by Admin-WS matched the serial number recorded in the CA01 issuance database.

## 3. Step 5.8 - Final PKI Acceptance Validation

### Purpose

Confirm the final operational state of the Project Polaris two-tier PKI without repeating the already completed implementation, artifact transport, or enrollment workflow.

### Estimated Duration

20-30 minutes.

### Requirements

- CA01 is online and domain connected.
- Admin-WS is online and domain connected.
- The Project Polaris Root CA certificate is trusted.
- The CA01 subordinate CA certificate is installed and active.
- The Admin-WS machine certificate has already been enrolled.
- An elevated Windows PowerShell session is available on CA01 and Admin-WS.

### Safety and Change Scope

The validation is read-only except for Step 5.8.5, which temporarily exports the public Admin-WS certificate to `%TEMP%`. No private key is exported. The temporary public certificate is removed within the same step.

Do not reinstall AD CS, reissue the certificate, repeat artifact transport, change CA registry settings, alter certificate templates, or modify firewall and SMB configuration during this validation. Stop and evaluate any unexpected result before making changes.

## 4. Validation Results

| Step | Validation gate | Evidence | Result |
|---|---|---|---|
| 5.8.1 | CA service state | `CertSvc` reported `Running` with start mode `Auto` | PASS |
| 5.8.2 | CA identity and request interface | Common name `Polaris Issuing CA`; CA type `1 / ENUM_ENTERPRISE_SUBCA`; `ICertRequest2` interface alive | PASS |
| 5.8.3 | Admin-WS certificate presence | Matching certificate in `LocalMachine\My`; private key present; expected EKUs present | PASS |
| 5.8.4 | Chain and revocation status | Three-element chain completed with `NoError` on every element | PASS |
| 5.8.5 | AIA/CDP and online verification | `certutil -urlfetch -verify` completed successfully; exit code `0`; leaf revocation check passed | PASS |
| 5.8.6 | CA issuance database correlation | Request `0x7`; Machine template; matching subject, validity, and serial; disposition `20 - Issued` | PASS |
| 5.8.7 | Post-issuance CA event health | No AD CS critical, error, or warning events after certificate issuance | PASS |

### Accepted Chain

1. `CN=ADMIN-WS.ad.polaris`
2. `CN=Polaris Issuing CA, DC=ad, DC=polaris`
3. `CN=Polaris Root CA`

All three chain elements returned `NoError`.

### Expected Root CA URL Behavior

The final `certutil -urlfetch -verify` output reported no AIA, CDP, or OCSP URLs for the self-signed Root CA element. This is expected because the Root CA is the terminal trust anchor and has no higher issuing authority. Overall URL and revocation verification completed successfully.

## 5. Completion Criteria

RB-010 is complete because all of the following are true:

- The CA01 Certification Authority service is running automatically.
- CA01 identifies as the approved Enterprise Subordinate CA.
- The CA request interface responds successfully.
- Admin-WS possesses the intended certificate and corresponding private key.
- The endpoint certificate chains through the issuing CA to the Project Polaris Root CA.
- Online chain and revocation verification succeeds.
- The CA01 database contains the matching issued-certificate record.
- No unresolved AD CS warning or error was detected after issuance.
- The validation introduced no configuration change and left no temporary public-certificate export behind.

## 6. Deferred Work Outside RB-010

The following items are deliberately excluded from RB-010 closeout and do not block completion:

- Independent verification of SMB persistence after reboot or logoff.
- Formal CA backup and isolated restore exercise.
- PKI monitoring and alerting implementation.
- Certificate renewal lifecycle procedures.
- Expanded auto-enrollment and certificate-template rollout.
- Broader endpoint enrollment beyond the validated Admin-WS machine certificate.

These items must remain in their applicable operational, maintenance, PKI, or Active Directory workstreams. They must not be treated as a reason to reopen frozen RB-010 implementation steps unless later evidence demonstrates a genuine implementation deficiency.

## 7. Formal Closeout Decision

**Decision:** Accept and freeze RB-010 implementation.

**Effective date:** 2026-08-13.

**Validated outcome:** The Project Polaris two-tier PKI is operational. `Polaris Root CA` anchors trust, `Polaris Issuing CA` performs domain-integrated issuance, and Admin-WS successfully holds and validates an issued machine certificate.

**Change control:** Any future change to frozen RB-010 content requires a documented revision supported by implementation evidence. Editorial consolidation may clarify wording but must not silently alter the accepted architecture, security boundaries, or validation result.

**Transition:** Resume completion of the remaining Active Directory structure. After the Active Directory milestone is complete, continue to the remaining Project Polaris milestones and cyber-range build.

---

# Appendix A - Published Step 5.8 Commands

## A.1 Step 5.8.1 - Validate CA Service State

Run on CA01 in an elevated Windows PowerShell session:

```powershell
Get-CimInstance Win32_Service -Filter "Name='CertSvc'" |
    Select-Object Name, State, StartMode
```

Accepted result: `CertSvc`, `Running`, `Auto`.

## A.2 Step 5.8.2 - Validate CA Identity and Request Interface

Run on CA01:

```powershell
certutil.exe -getreg CA\CommonName
certutil.exe -getreg CA\CAType
certutil.exe -ping
```

Accepted result:

- Common name: `Polaris Issuing CA`
- CA type: `1 / ENUM_ENTERPRISE_SUBCA`
- Request interface: alive
- Commands complete successfully

## A.3 Step 5.8.3 - Locate the Issued Admin-WS Certificate

Run on Admin-WS:

```powershell
$IssuedCerts = Get-ChildItem `
    -Path Cert:\CurrentUser\My, Cert:\LocalMachine\My `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Issuer -like '*CN=Polaris Issuing CA*'
    }

$IssuedCerts |
    Select-Object `
        @{Name='Store'; Expression={
            if ($_.PSParentPath -like '*CurrentUser*') {
                'CurrentUser\My'
            }
            else {
                'LocalMachine\My'
            }
        }},
        Subject,
        Issuer,
        SerialNumber,
        Thumbprint,
        NotBefore,
        NotAfter,
        HasPrivateKey,
        @{Name='EnhancedKeyUsage'; Expression={
            $_.EnhancedKeyUsageList.FriendlyName -join '; '
        }} |
    Format-List
```

## A.4 Step 5.8.4 - Validate the Certificate Chain

Run on Admin-WS:

```powershell
$Thumbprint = '9033E3E0243F9EA1E17965D82E5EA11BE941DA53'

$Certificate = Get-Item `
    -Path "Cert:\LocalMachine\My\$Thumbprint" `
    -ErrorAction Stop

$Chain = New-Object `
    System.Security.Cryptography.X509Certificates.X509Chain

$Chain.ChainPolicy.RevocationMode = `
    [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Online

$Chain.ChainPolicy.RevocationFlag = `
    [System.Security.Cryptography.X509Certificates.X509RevocationFlag]::ExcludeRoot

$Chain.ChainPolicy.VerificationFlags = `
    [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag

$Chain.ChainPolicy.UrlRetrievalTimeout = New-TimeSpan -Seconds 30

$ChainValid = $Chain.Build($Certificate)

"ChainValid = $ChainValid"
"ChainStatus:"

if ($Chain.ChainStatus.Count -eq 0) {
    'NoError'
}
else {
    $Chain.ChainStatus |
        Select-Object Status, StatusInformation |
        Format-List
}

for ($Index = 0; $Index -lt $Chain.ChainElements.Count; $Index++) {
    $Element = $Chain.ChainElements[$Index]

    "ChainElement[$Index]"
    "Subject  = $($Element.Certificate.Subject)"
    "Issuer   = $($Element.Certificate.Issuer)"
    "NotAfter = $($Element.Certificate.NotAfter)"

    if ($Element.ChainElementStatus.Count -eq 0) {
        'Status   = NoError'
    }
    else {
        $Element.ChainElementStatus |
            Select-Object Status, StatusInformation |
            Format-List
    }

    ''
}
```

## A.5 Step 5.8.5 - Validate AIA and CRL Retrieval

Run on Admin-WS:

```powershell
$Thumbprint = '9033E3E0243F9EA1E17965D82E5EA11BE941DA53'

$Certificate = Get-Item `
    -Path "Cert:\LocalMachine\My\$Thumbprint" `
    -ErrorAction Stop

$ValidationFile = Join-Path `
    $env:TEMP `
    'Polaris-AdminWS-5.8.5.cer'

Export-Certificate `
    -Cert $Certificate `
    -FilePath $ValidationFile `
    -Type CERT `
    -Force |
    Out-Null

certutil.exe -urlfetch -verify $ValidationFile

$VerifyExitCode = $LASTEXITCODE
"CertUtilVerifyExitCode = $VerifyExitCode"

Remove-Item -Path $ValidationFile -Force

"TemporaryCertificateRemoved = $(-not (Test-Path $ValidationFile))"
```

Accepted result:

- Verification completes successfully.
- Exit code is `0`.
- Leaf certificate revocation check passes.
- Temporary certificate removal returns `True`.

## A.6 Step 5.8.6 - Confirm the CA01 Issuance Record

Run on CA01:

```powershell
certutil.exe -view `
    -restrict "Disposition=20,CommonName=ADMIN-WS.ad.polaris" `
    -out "RequestID,RequesterName,CommonName,CertificateTemplate,NotBefore,NotAfter,SerialNumber,Disposition"
```

Accepted result: one matching issued record with Request ID `0x7`, Machine template, matching subject, validity and serial number, and disposition `20 - Issued`.

## A.7 Step 5.8.7 - Check for Post-Issuance AD CS Errors

Run on CA01:

```powershell
$ValidationStart = [datetime]'2026-08-13 12:18:40'

$AdcsEvents = Get-WinEvent `
    -FilterHashtable @{
        LogName      = 'Application'
        ProviderName = 'Microsoft-Windows-CertificationAuthority'
        StartTime    = $ValidationStart
        Level        = 1, 2, 3
    } `
    -ErrorAction SilentlyContinue

if ($AdcsEvents) {
    $AdcsEvents |
        Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Format-List
}
else {
    'PASS: No AD CS critical, error, or warning events were recorded after certificate issuance.'
}
```

Accepted result: no AD CS critical, error, or warning events recorded after certificate issuance.

---

**End of RB-010 controlled closeout record.**
