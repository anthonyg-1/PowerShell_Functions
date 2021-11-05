function Get-ResponseHeader ([Uri]$Uri) { 
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
