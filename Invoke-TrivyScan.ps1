function Invoke-TrivyScan {
    [CmdletBinding()]
    [Alias('trivyscan')]
    [OutputType([PSCustomObject])]
    Param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
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
        $trivyScanResults = trivy image -f json --severity "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL" $Image 2>$null | ConvertFrom-Json -Depth 25

        $trivyScanResults.Results.Vulnerabilities |
            Select-Object @{Name = "Image"; Expression = { $Image } }, VulnerabilityID, Title, Description, Severity,
                            PkgID, @{Name = "CweIDs"; Expression = { $_.CweIDs -join ", " } }, PkgName, InstalledVersion,
                            Status, @{Name = "References"; Expression = { ($_.References -split ",") -join ", " } },
                            PublishedDate, LastModifiedDate, PrimaryURL
    }
}
