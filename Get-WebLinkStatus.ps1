function Get-WebLinkStatus {
    [CmdletBinding()]
    [Alias('gwls')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)][Alias('u')][Uri]$Uri,
        [Parameter(Mandatory = $false, Position = 1)][Alias('d')][int]$Depth = 2,
        [Parameter(Mandatory = $false, Position = 2)][Alias("h")][System.Collections.Hashtable]$Headers,
        [hashtable]$Visited = @{}
    )
    BEGIN {
        if (($PSVersionTable.PSVersion.Major -lt 7) -and ($PSVersionTable.PSVersion.Minor -lt 4)) {
            $ArgumentException = [ArgumentException]::new("This function requires PowerShell version 7.4.0 or higher")
            Write-Error -Exception $ArgumentException -ErrorAction Stop
        }
    }
    PROCESS {
        $targetUri = $Uri.AbsoluteUri

        # Avoid visiting the same URL more than once
        if ($Visited.ContainsKey($targetUri)) {
            return
        }

        $Visited[$targetUri] = $true

        $iwrParams = @{Uri       = $Uri
            Method               = "Get"
            UseBasicParsing      = $true
            SkipCertificateCheck = $true
            SkipHttpErrorCheck   = $true
            ErrorAction          = "Stop"
            AllowInsecureRedirect = $true
        }

        if ($PSBoundParameters.ContainsKey("Headers")) {
            $iwrParams.Add("Headers", $Headers)
        }

        $response = Invoke-WebRequest @iwrParams

        [PSCustomObject]@{
            Uri        = $targetUri
            StatusCode = $response.StatusCode
        }

        # If the depth is 0, we stop here
        if ($Depth -le 0) {
            return
        }

        # Extract links from the HTML content
        $links = $response.Links | Where-Object { $_.href -match "^http" } | Select-Object -ExpandProperty href
        foreach ($link in $links) {
            # Recursively visit each link
            Get-WebLinkStatus -Uri $link -Depth ($Depth - 1) -Visited $Visited
        }
    }
}
