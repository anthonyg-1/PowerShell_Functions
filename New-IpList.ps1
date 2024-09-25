function New-IpList {
    param (
        [string]$BaseNetwork
    )

    # Split base network into octets:
    $octets = $BaseNetwork.Split('.')

    # First two octets from base network, iterate over 3rd and 4th octets (limit to 254):
    for ($i = 0; $i -le 254; $i++) {
        for ($j = 0; $j -le 254; $j++) {
            $ip = "$($octets[0]).$($octets[1]).$i.$j"
            # Write IP address to pipeline
            Write-Output $ip
        }
    }
}
