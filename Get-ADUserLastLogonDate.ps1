function Get-ADUserLastLogonDate {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)][Microsoft.ActiveDirectory.Management.ADUser]$Identity,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 1)][String]$Server = $env:USERDNSDOMAIN
    )
    BEGIN {
        $requiredModuleName = "ActiveDirectory"
        if (-not(Get-Module -Name $requiredModuleName)) {
            Import-Module -Name $requiredModuleName -ErrorAction Stop
        }

        $domain = Get-ADDomain -Server $Server | Select-Object -ExpandProperty DNSRoot
    }
    PROCESS {
        $allDcs = Get-ADDomainController -Filter * -Server $Server

        $allDcs | ForEach-Object {
            [bool]$canConnect = Test-NetConnection -ComputerName $_.Name -Port 9389 -InformationLevel Quiet -WarningAction SilentlyContinue

            if ($canConnect) {
                Get-ADUser -Identity $Identity -Server $_.HostName -Properties LastLogonDate, WhenCreated, PasswordLastSet
            }
        } | Sort-Object LastLogonDate -Descending |
        Select-Object Name,
        @{Name = "LastLogon"; Expression = {
                if ($null -eq $_.LastLogonDate) {
                    "Never"
                }
                else {
                    $_.LastLogonDate
                }
            }
        }, WhenCreated,
        @{Name = "PasswordLastSet"; Expression = {
                if ($null -eq $_.PasswordLastSet ) {
                    "Never"
                }
                else {
                    $_.PasswordLastSet
                }
            }
        },
        @{Name = "Domain"; Expression = { $domain } }, Enabled -First 1
    }
}
