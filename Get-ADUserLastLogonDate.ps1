function Get-ADUserLastLogonDate {
    <#
    .SYNOPSIS
        Gets an Active Directory user's last logon date.
    .DESCRIPTION
        Gets an Active Directory user's last logon date, password last set, when created, and other applicable account metadata.
    .EXAMPLE
        Get-ADUserLastLogonDate $env:USERNAME

        Gets the logged-on user's last logon date from Active Directory.
    .EXAMPLE
        Get-ADUser -Filter {Surname -eq "Smith"} | Get-ADUserLastLogonDate | Export-Csv -Path SmithLastLogons.csv -NoTypeInformation

        Gets all users from the Active Directory with a last name of "Smith" and generates a report of their last logon dates exported to a CSV file.
    .INPUTS
        System.String
            A string value is received by the Identity parameter.
    .OUTPUTS
        PSCustomObject
    .NOTES
        This function requires PowerShell 7 or above as well as the ActiveDirectory and PSTcpIp modules.
    .LINK
        https://learn.microsoft.com/en-us/powershell/module/activedirectory/?view=windowsserver2025-ps
        https://github.com/anthonyg-1/PSTcpIp/tree/main/PSTcpIp
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)][String]$Identity,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 1)][String]$Server = $env:USERDNSDOMAIN
    )
    BEGIN {
        if (-not($PSVersionTable.PSVersion.Major -ge 7)) {
            Write-Error -Message "This function requires PowerShell 7.0.0 or above. Execution halted." -Category NotImplemented -ErrorAction Stop
        }

        $requiredModuleNames = @("ActiveDirectory", "PSTcpIp")

        foreach ($module in $requiredModuleNames) {
            if (-not(Get-Module -Name $module)) {
                Import-Module -Name $module -ErrorAction Stop
            }
        }

        $domain = Get-ADDomain -Server $Server | Select-Object -ExpandProperty DNSRoot
    }
    PROCESS {
        $allDcs = Get-ADDomainController -Filter * -Server $Server

        $targetUserRecords = [System.Collections.ArrayList]::new()

        $allDcs | ForEach-Object {
            $domainController = $_.HostName

            [bool]$canConnect = Test-TcpConnection -DNSHostName $domainController -Port 9389 -Quiet

            if ($canConnect) {
                $targetUser = Get-ADUser -Identity $Identity -Server $domainController -Properties LastLogon, LastLogonDate, WhenCreated, PasswordLastSet

                $latestLastLogon = $null
                $lastLogon = Get-Date -Date $([DateTime]::FromFileTime($targetUser.LastLogon).ToString('MM/dd/yyyy hh:mm:ss tt'))
                $lastLogonDate = $targetUser.LastLogonDate

                if ($lastLogon -ge $lastLogonDate) {
                    $latestLastLogon = $lastLogon
                }
                else {
                    $latestLastLogon = $lastLogonDate
                }

                $passwordLastSet = $targetUser.PasswordLastSet
                if ($null -eq $passwordLastSet ) {
                    $passwordLastSet = "Never"
                }

                if ($latestLastLogon -match "1600") {
                    $latestLastLogon = "Never"
                }

                $targetUserRecord = [PSCustomObject]@{
                    Name              = $targetUser.Name
                    SamAccountName    = $targetUser.SamAccountName
                    DistinguishedName = $targetUser.DistinguishedName
                    LastLogonDetected = $latestLastLogon
                    WhenCreated       = $targetUser.WhenCreated
                    PasswordLastSet   = $passwordLastSet
                    Domain            = $domain
                    Enabled           = $targetUser.Enabled
                }

                $targetUserRecords.Add($targetUserRecord) | Out-Null
            }
            else {
                $warningMessage = "Unable to connect to domain controller {0} over TCP port 9389. Last logon data may not be accurate as a result." -f $domainController
                Write-Warning -Message $warningMessage
            }
        }
        $targetUserRecords | Sort-Object -Property LastLogonDetected -Descending | Select-Object -First 1
    }
}
