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
    [Alias('gll', 'gadull', 'gull')]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)][Alias('i')][String]$Identity,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $false,
            Position = 1)][Alias('Domain', 'd', 's')][String]$Server = $env:USERDNSDOMAIN
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
                $targetUser = $null

                try {
                    $targetUser = Get-ADUser -Identity $Identity -Server $domainController -Properties LastLogon, LastLogonDate, WhenCreated, PasswordLastSet -ErrorAction Stop

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

                    $detectedLastLogon = $null
                    if (($null -eq $latestLastLogon) -or ($latestLastLogon.Year -eq 1600)) {
                        $detectedLastLogon = "Never"
                    }
                    else {
                        $detectedLastLogon = $latestLastLogon
                    }

                    if ($null -ne $targetUser) {
                        $targetUserRecord = [PSCustomObject]@{
                            Name              = $targetUser.Name
                            SamAccountName    = $targetUser.SamAccountName
                            DistinguishedName = $targetUser.DistinguishedName
                            LastLogonDate = $detectedLastLogon
                            WhenCreated       = $targetUser.WhenCreated
                            PasswordLastSet   = $passwordLastSet
                            Domain            = $domain
                            Enabled           = $targetUser.Enabled
                        }

                        $targetUserRecords.Add($targetUserRecord) | Out-Null
                    }
                }
                catch {
                    $exceptionMessage = "Cannot find an object with identity: {0}" -f $Identity
                    $ArgumentException = New-Object -TypeName System.ArgumentException -ArgumentList $exceptionMessage
                    Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Continue
                }
            }
            else {
                $warningMessage = "Unable to connect to domain controller {0} over TCP port 9389. Last logon data may not be accurate as a result." -f $domainController
                Write-Warning -Message $warningMessage
            }
        }
        $targetUserRecords | Sort-Object -Property LastLogonDetected -Descending | Select-Object -First 1
    }
}
