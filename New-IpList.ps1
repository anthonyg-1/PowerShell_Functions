function New-IpList {
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'IPV4Subnet')]
        [ValidateLength(7, 15)]
        [Alias('BaseNetwork', 's', 'is')]
        $IPV4Subnet
    )
    PROCESS {
        [bool]$isIp = $false
        try {
            [IPAddress]::Parse($IPV4Subnet) | Out-Null
            $isIp = $true
        }
        catch {
            $isIp = $false
        }

        if (-not($isIp)) {
            $ArgumentException = [ArgumentException]::new("The following value passed to the IPV4Subnet parameter is not a valid IPv4 subnet: " -f $IPV4Subnet)
            Write-Error -Exception $ArgumentException -Category ArgumentException -ErrorAction Stop
        }

        # Split base network into octets:
        $octets = $IPV4Subnet.Split('.')

        # First two octets from base network, iterate over 3rd and 4th octets (limit to 254):
        for ($i = 0; $i -le 254; $i++) {
            for ($j = 0; $j -le 254; $j++) {
                $ip = "$($octets[0]).$($octets[1]).$i.$j"

                # Write each IP address to pipeline:
                Write-Output $ip
            }
        }
    }
}
