function Get-MappedDriveInformation {
    [CmdletBinding()]
    param()

    Process {
        $wmiQuery = 'Select * from Win32_NetworkConnection'
        $wmiQueryResult = Get-WmiObject -Query $wmiQuery

        $wmiQueryResult | ForEach-Object {
            [bool]$connected = $false
            if ($_.ConnectionState -eq "Connected") {
                $connected = $true
            }

            [PSCustomObject]@{
                DriveName             = $_.LocalName
                RemoteSharePath       = $_.RemoteName
                AuthenticationContext = $_.UserName
                Connected             = $connected
            }
        }
    }
}
