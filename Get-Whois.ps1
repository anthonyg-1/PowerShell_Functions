function Get-Whois {
    [CmdletBinding()]
    [Alias('pswhois')]
    [OutputType([PSCustomObject])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)][Alias('d')][String]$Domain
    )
    BEGIN {
        #requires -Version 7

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
        $whoisResults = & $whoisPath $Domain | awk '/Domain Name:/,/DNSSEC:/' | sed -s 's/: */,/'

        $resultsTable = @{}

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

        $whoisData = New-Object -TypeName PSObject -Property $resultsTable

        return $whoisData
    }
}
