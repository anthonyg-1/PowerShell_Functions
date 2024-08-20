function Get-Whois {
    [CmdletBinding()]
    [Alias('pswhois')]
    [OutputType([PSCustomObject])]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)][ValidateLength(1, 250)][Alias('d')][String]$Domain
    )
    BEGIN {
        #requires -Version 7

        if (-not($IsLinux)) {
            $ApplicationException = [System.ApplicationException]::new("This function is only compatible with Linux.")
            Write-Error -Exception $ApplicationException -Category InvalidOperation -ErrorAction Stop
        }

        $whoisCommandData = $null
        $whoisPath = ""
        try {
            $whoisCommandData = Get-Command -Name "whois" -ErrorAction Stop
            $whoisPath = $whoisCommandData.Source
        }
        catch {
            $ArgumentException = [System.ArgumentException]::new("Unable to find dependency whois command.")
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

    }
    PROCESS {
        $whoisData = $null

        $whoisResults = & $whoisPath $Domain 2>$null | awk '/Domain Name:/,/DNSSEC:/' 2>$null | sed -s 's/: */,/' 2>$null

        if ($whoisResults) {
            $resultsTable = @{"Domain" = $Domain }

            $whoisResults | ForEach-Object {
                $lineArray = $_.Split(",")
                $key = ($lineArray[0]).Replace(" ", "").Trim()
                $value = ($lineArray[1]).Trim()

                if (-not($resultsTable.ContainsKey($key))) {
                    $resultsTable.Add($key, $value)
                }
                else {
                    $priorValues = @($resultsTable.$key)
                    $currentValue = $value
                    $valueArray = $priorValues += $currentValue
                    $resultsTable.$key = $valueArray
                }
            }

            $expirationDateUTC = $null
            $expirationDateString = $resultsTable.RegistryExpiryDate

            if ($expirationDateString) {
                $expirationDateUTC = Get-Date -Date $expirationDateString -AsUTC
            }

            $resultsTable.Add("ExpirationDate", $expirationDateUTC)

            $whoisData = New-Object -TypeName PSObject -Property $resultsTable
        }

        return $whoisData
    }
}
