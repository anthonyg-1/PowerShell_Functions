function Invoke-TrivyScan {
    [CmdletBinding()]
    [Alias('trivyscan')]
    [OutputType([PSCustomObject])]
    Param (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)][Alias('i')][String]$Image
    )
    BEGIN {
        $trivyBinary = "trivy"
        try {
            Get-Command $trivyBinary -ErrorAction Stop | Out-Null
        }
        catch {
            $fileNotFoundExceptionMessage = "Trivy was not found. Please see https://github.com/aquasecurity/trivy for installation instructions."
            $FileNotFoundException = [System.IO.FileNotFoundException]::new($fileNotFoundExceptionMessage)
            Write-Error -Exception $FileNotFoundException -Category InvalidData -ErrorAction Stop
        }
    }
    PROCESS {
        $trivyScanResults = trivy image -f json --severity "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL" $Image | ConvertFrom-Json

        $trivyScanResults.Results.Vulnerabilities |
            Select-Object @{Name="Image";Expression={$Image}}, VulnerabilityID, Title, Description, Severity,
                            PkgID, @{n = "CweIDs"; e = { $_.CweIDs -join ", " } }, PkgName, InstalledVersion,
                            Status, @{n = "References"; e = { ($_.References -split ",") -join ", " } },
                            PublishedDate, LastModifiedDate, PrimaryURL
    }
}
