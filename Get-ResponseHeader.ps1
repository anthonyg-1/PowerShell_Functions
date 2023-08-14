Sure! Here's a commented-based help for your PowerShell function:

```powershell
<#
.SYNOPSIS
   Retrieves the response headers from a web endpoint.

.DESCRIPTION
   The Get-WebResponseHeader function retrieves the response headers from a specified web endpoint using Invoke-WebRequest cmdlet. It returns a collection of headers with the header name as the key.

.PARAMETER Uri
   Specifies the Uniform Resource Identifier (URI) of the web endpoint. This parameter is mandatory and can be provided through the pipeline or by property name.

.EXAMPLE
   Get-WebResponseHeader -Uri "https://example.com"
   Retrieves the response headers from the specified web endpoint.

.EXAMPLE
   "https://example.com" | Get-WebResponseHeader
   Retrieves the response headers from the web endpoint provided through the pipeline.

.OUTPUTS
   System.Management.Automation.PSCustomObject
   Returns a collection of headers with the header name as the key.

.NOTES
   Author: [Your Name]
   Date: [Date]

#>

function Get-WebResponseHeader {
    [CmdletBinding()]
    [Alias('gwrh')]
    [OutputType([PSCustomObject])]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)][Alias('u')][Uri]$Uri
    )
    PROCESS {
        try {
            # Get response headers:
            $responseHeaders = Invoke-WebRequest -Uri $Uri.AbsoluteUri | Select-Object -ExpandProperty Headers -ErrorAction Stop

            # Create sorted table:
            $sortedHeaders = $responseHeaders.GetEnumerator() | Sort-Object -Property Key

            # Create empty sorted hash table and populate (can't send PSCustomObject a table that's has GetEnumerator() called on it:
            $headersToReturn = [ordered]@{}
            $sortedHeaders | ForEach-Object { $headersToReturn.Add($_.Key, $_.Value) }

            # Return collection of headers with header name as key:
            $headerObjectCollection = New-Object -TypeName PSCustomObject -Property $headersToReturn
            return $headerObjectCollection
        }
        catch {
            Write-Error -Exception $_.Exception -ErrorAction Stop
        }
    }
}
```

Make sure to replace `[Your Name]` and `[Date]` with your actual name and the date when you wrote the help documentation.
