function Get-OutlookCalendar {
    [CmdletBinding(DefaultParameterSetName = 'Today')]
    [Alias('goc')]
    [OutputType([PSCustomObject])]
    Param
    (
        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true, ParameterSetName = "Today",
            Position = 0)][Alias('t')][Switch]$Today,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true, ParameterSetName = "StartEnd",
            Position = 0)][Alias('start', 's')][DateTime]$StartDate,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true, ParameterSetName = "StartEnd",
            Position = 1)][Alias('end', 'e')][DateTime]$EndDate
    )
    BEGIN {
        $targetPsVersion = 5
        if ($PSVersionTable.PSVersion.Major -ne $targetPsVersion) {
            $functionName = (Get-PSCallStack).Command[0]

            $argExcepMessage = "{0} : This function will only run on PowerShell with a major version of {1}." -f $functionName, $targetPsVersion
            $ArgumentException = New-Object -TypeName System.ArgumentException -ArgumentList $argExcepMessage
            # Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
            throw $ArgumentException
        }

        Add-Type -Assembly "Microsoft.Office.Interop.Outlook" | Out-Null

        $olFolders = "Microsoft.Office.Interop.Outlook.OlDefaultFolders" -as [type]
        $outlook = New-Object -ComObject Outlook.Application
        $namespace = $outlook.GetNameSpace("MAPI")
        $folder = $namespace.getDefaultFolder($olFolders::olFolderCalendar)
    }
    PROCESS {
        [PSCustomObject]$sortedFilteredResult = $null

        $acceptanceTable = @{
            2 = "Declined"
            3 = "Accepted or Tentative"
            5 = "None"
        }

        $unfilteredResults = $folder.items | ForEach-Object {
            $item = $_

            $timeDelta = $item.End - $item.Start

            $Duration = @{Name = "Duration"; Expression = { $timeDelta } }
            $Response = @{Name = "Response"; Expression = { $acceptanceTable[$_.ResponseStatus] } }

            $item | Select-Object -Property Subject, Start, End, $Duration, $Response
        }

        [PSCustomObject]$filteredResult = $null
        if ($PSBoundParameters.ContainsKey("StartDate")) {
            [DateTime]$adjustedEndDate = $EndDate.AddDays(1)
            $filteredResult = $unfilteredResults | Where-Object { ($_.Start -ge $StartDate) -and ($_.End -le $adjustedEndDate) }
        }
        else {
            $calculatedStartTime = (get-date).Date
            $calculatedEndTime = ((get-date).AddDays(+1)).date

            $filteredResult = $unfilteredResults | Where-Object { ($_.Start -ge $calculatedStartTime) -and ($_.End -le $calculatedEndTime) }
        }

        $sortedFilteredResult = $filteredResult | Sort-Object -Property Start

        return $sortedFilteredResult
    }
    END {
        $outlook.Quit()
        $outlook = $null
    }
}
