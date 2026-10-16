Set-StrictMode -Version Latest

function New-RecoveryRelayTransportPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$ExecutionRequest
    )

    return [PSCustomObject]@{
        operation = [string]$ExecutionRequest.Operation
        operation_id = [string]$ExecutionRequest.OperationId
        artifact_name = [string]$ExecutionRequest.Artifact
    }
}

function Invoke-RecoveryRelaySshTransport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$TransportRequest
    )

    Test-RecoveryRelaySshTransportRequest `
        -TransportRequest $TransportRequest |
        Out-Null

    $Payload = New-RecoveryRelayTransportPayload -ExecutionRequest $TransportRequest

    Write-Verbose ($Payload | ConvertTo-Json -Depth 5)

    throw [System.NotImplementedException]::new(
        'Recovery Relay SSH transport execution has not yet been implemented.'
    )
}

function Get-RecoveryRelaySshConfiguration {
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        Host           = $null
        Port           = $null
        Username       = $null
        PrivateKeyPath = $null
        KnownHostsPath = $null
    }
}

function Test-RecoveryRelaySshTransportRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$TransportRequest
    )

    $requiredProperties = @(
        'Operation',
        'OperationId',
        'Artifact'
    )

    $actualProperties = @(
        $TransportRequest.PSObject.Properties.Name
    )

    foreach ($requiredProperty in $requiredProperties) {
        if ($actualProperties -cnotcontains $requiredProperty) {
            throw [System.ArgumentException]::new(
                "Recovery Relay SSH transport request is missing required property '$requiredProperty'."
            )
        }
    }

    foreach ($actualProperty in $actualProperties) {
        if ($requiredProperties -cnotcontains $actualProperty) {
            throw [System.ArgumentException]::new(
                "Recovery Relay SSH transport request contains unsupported property '$actualProperty'."
            )
        }
    }

    return $true
}

Export-ModuleMember -Function Invoke-RecoveryRelaySshTransport