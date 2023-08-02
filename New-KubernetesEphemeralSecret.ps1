function Set-KubernetesSecretValue {
    <#
    .SYNOPSIS
        Sets a Kubernetes secret value.
    .DESCRIPTION
        Sets/updates a Kubernetes secret value for a generic secret.
    .PARAMETER Namespace
        The Kubernetes namespace that secret resides in.
    .PARAMETER SecretName
        The name of the Kubernetes secret.
    .PARAMETER SecretData
        The data for the Kubernetes secret as a PSCredential where the UserName will be the key and the Password will be the secret value.
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretValue = '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        Set-KubernetesSecretValue  -SecretName "my-secret" -SecretData $secretDataCred

        Sets a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd'.
    .EXAMPLE
        $secretDataName = "mypassword"
        $secretValue = 'IUrwnq8ZNbWMF5eKSviL&3xf^z42to0V!haHAE'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        Set-KubernetesSecretValue -Namespace "apps" -SecretName "my-password" -SecretData $secretDataCred

        Sets a Kubernetes secret in the apps namespace with a name of 'my-password' with a key of 'mypassword' and a value of 'IUrwnq8ZNbWMF5eKSviL&3xf^z42to0V!haHAE'.
    .EXAMPLE
        $secretDataName = "myapikey"
        $secretValue = '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        sksv -s "my-secret" -d $secretDataCred

        Sets a Kubernetes secret in the default namespace with a name of 'my-secret' with a key of 'myapikey' and a value of '2@GaImh59O3C8!TMwLSf$gVrjsuiDZAEveKxkd'.
    .EXAMPLE
        $secretDataName = "mypassword"
        $secretValue = 'IUrwnq8ZNbWMF5eKSviL&3xf^z42to0V!haHAE'
        $secretDataValue = $secretValue | ConvertTo-SecureString -AsPlainText -Force
        $secretDataCred = New-Object -TypeName PSCredential -ArgumentList $secretDataName, $secretDataValue
        sksv -n apps -s "my-secret" -d $secretDataCred

        Sets a Kubernetes secret in the apps namespace with a name of 'my-password' with a key of 'mypassword' and a value of 'IUrwnq8ZNbWMF5eKSviL&3xf^z42to0V!haHAE'.
#>
    [CmdletBinding()]
    [Alias('sksv', 'sk8ss')]
    [OutputType([void])]
    Param
    (
        [Parameter(Mandatory = $false)][Alias('ns')][String]$Namespace = 'default',

        [Parameter(Mandatory = $true)][Alias('s')][String]$SecretName,

        [Parameter(Mandatory = $true)][ValidateNotNull()][Alias('d')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$SecretData
    )
    BEGIN {
        try {
            Get-Command -Name kubectl -ErrorAction Stop | Out-Null
        }
        catch {
            $FileNotFoundException = [IO.FileNotFoundException]::new("Unable to find kubectl. Execution halted.")
            Write-Error -Exception $FileNotFoundException -ErrorAction Stop
        }

        $allNamespaces = $(kubectl get namespaces --output=json | ConvertFrom-Json).items.metadata.name
        $allSecrets = $(kubectl get secrets -n $Namespace --output=json | ConvertFrom-Json).items.metadata.name

        if ($Namespace -notin $allNamespaces) {
            $ArgumentException = [ArgumentException]::new("The following namespace was not found: $Namespace")
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        if ($(kubectl auth can-i update secret).ToLower() -ne "yes") {
            $SecurityException = [Security.SecurityException]::new("Current context cannot set secret values within the $Namespace namespace.")
            Write-Error -Exception $SecurityException -ErrorAction Stop
        }
    }
    PROCESS {
        if (-not($SecretName -in $allSecrets)) {
            $argExceptionMessage = "The following secret was not found {0}:{1}" -f $Namespace, $SecretName
            $ArgumentException = [ArgumentException]::new($argExceptionMessage)
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        $secretKeyName = $SecretData.UserName
        $secretDataValue = $SecretData.GetNetworkCredential().Password

        [string[]]$existingSecretDataKeys = ""
        try {
            $existingSecretDataKeys = (($(kubectl get secret -n $Namespace $SecretName --output=json 2>&1) |
                    ConvertFrom-Json -ErrorAction Stop).data | Get-Member |
                Where-Object -Property MemberType -eq "NoteProperty") |
            Select-Object -ExpandProperty Name
        }
        catch {
            $parseExceptionMessage = "Unable to parse kubectl output from the following secret: {1}:{2}" -f $Namespace, $SecretName
            $ParseException = [Management.Automation.ParseException]::new($parseExceptionMessage)
            Write-Error -Exception $ParseException -ErrorAction Stop
        }

        if (-not($secretKeyName -in $existingSecretDataKeys)) {
            $argExceptionMessage = "The key '{0}' does not exist in the following secret: {1}:{2}" -f $secretKeyName, $Namespace, $SecretName
            $ArgumentException = [ArgumentException]::new($argExceptionMessage)
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }

        # Base64 encode the retrieved/generated secret, serialize hashtable to JSON and patch:
        $encodedSecretValue = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($secretDataValue))

        # Construct key value pairs and serialize to compressed JSON array for patch operation:
        $patchData = @{op = "replace"
            path          = "/data/$secretKeyName"
            value         = $encodedSecretValue
        } | ConvertTo-Json -AsArray -Compress

        [PSCustomObject]$patchResult = $null
        try {
            $patchResult = $(kubectl patch secret -n $Namespace $SecretName --type='json' -p $patchData --output=json 2>&1) | ConvertFrom-Json -ErrorAction Stop

            if ($patchResult.metadata.name -eq $SecretName) {
                Write-Verbose -Message ("Updated the following generic secret: {0}:{1}" -f $Namespace, $SecretName)
            }

            # Parse kubectl get... in order to return an object to the pipeline:
            [PSCustomObject]$secretGetResult = $(kubectl get secrets --namespace=$Namespace $SecretName --output=json 2>&1) | ConvertFrom-Json -ErrorAction Stop
            $dataKeys = $secretGetResult.data | Get-Member | Where-Object -Property MemberType -eq NoteProperty | Select-Object -ExpandProperty Name
            $deserializedGetOutput = [PSCustomObject]@{
                Name      = $secretGetResult.metadata.name
                Namespace = $secretGetResult.metadata.namespace
                Type      = $secretGetResult.type
                DataCount = $dataKeys.Count
                DataKeys  = $dataKeys
                CreatedOn = $secretGetResult.metadata.creationTimestamp
            }

            Write-Output -InputObject $deserializedGetOutput
        }
        catch {
            $ArgumentException = [ArgumentException]::new("Unable to update the following secret in the $Namespace namespace: $SecretName")
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }
    }
}
