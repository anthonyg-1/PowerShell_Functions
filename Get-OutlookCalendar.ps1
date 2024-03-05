function Get-OutlookCalendar {
    [CmdletBinding()]
    [Alias('goc')]
    [OutputType([PSCustomObject])]
    Param
    (
        [Parameter(Mandatory = $true,
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
        Add-Type -Assembly "Microsoft.Office.Interop.Outlook" | Out-Null

        $olFolders = "Microsoft.Office.Interop.Outlook.OlDefaultFolders" -as [type]
        $outlook = New-Object -ComObject Outlook.Application
        $namespace = $outlook.GetNameSpace("MAPI")
        $folder = $namespace.getDefaultFolder($olFolders::olFolderCalendar)
    }
    PROCESS {
        [PSCustomObject]$sortedFilteredResult = $null

        $unfilteredResults = $folder.items | ForEach-Object {
            $item = $_
            $timeDelta = $item.End - $item.Start
            $Duration = @{Name = "Duration"; Expression = { $timeDelta } }
            $item | Select-Object -Property Subject, Start, End, $Duration
        }

        [PSCustomObject]$filteredResult = $null
        if ($PSBoundParameters.ContainsKey("Today")) {
            $calculatedStartTime = (get-date).Date
            $calculatedEndTime = ((get-date).AddDays(+1)).date

            $filteredResult = $unfilteredResults | Where-Object { ($_.Start -ge $calculatedStartTime) -and ($_.End -le $calculatedEndTime) }
        }
        else {
            [DateTime]$adjustedEndDate = $EndDate.AddDays(1)
            $filteredResult = $unfilteredResults | Where-Object { ($_.Start -ge $StartDate) -and ($_.End -le $adjustedEndDate) }
        }

        $sortedFilteredResult = $filteredResult | Sort-Object -Property Start

        return $sortedFilteredResult
    }
    END {
        $outlook.Quit()
        $outlook = $null
    }
}
