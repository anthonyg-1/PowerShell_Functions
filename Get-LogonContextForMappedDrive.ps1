function Get-LogonContextForMappedDrive {
    [CmdletBinding()]
    param()

    PROCESS {
        $mappedDrives = Get-WmiObject -Class Win32_MappedLogicalDisk

        $mappedDrives | ForEach-Object {
            $logonContext = "{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME
            $logonSecurityContext = Get-WmiObject -Class Win32_LogonSession -Filter "Name='$($_.Name)'"

            if ($null -ne $logonSecurityContext) {
                $logonContext = $logonSecurityContext
            }

            [PSCustomObject]@{
                LogonContext = $logonContext
                VolumeName   = $_.VolumeName
                UncPath      = $_.ProviderName
                SourceSystem = $_.SystemName
                DriveLetter  = $_.Name
            }
        }
    }
}
