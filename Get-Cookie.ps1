function Get-Cookie {
    <#
    .SYNOPSIS
        Gets cookies.
    .DESCRIPTION
        See synopsis.
    .EXAMPLE
        Get-Cookie -Uri "https://www.linkedin.com"
    .PARAMETER Uri
        Specifies the Uniform Resource Identifier (URI) of the internet resource to which the web request is sent.
    .LINK
        https://www.youtube.com/watch?v=BovQyphS8kA
#>
    [CmdletBinding()]
    [OutputType([System.Net.Cookie[]])]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)][System.Uri]$Uri
    )
    PROCESS {
        [System.Net.Cookie[]]$cookies = $null

        try {
            Invoke-WebRequest -Uri $Uri -SessionVariable websession -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error -Exception $_.Exception -ErrorAction Stop
        }

        $cookies = $websession.Cookies.GetCookies($Uri)

        return $cookies
    }
}
