function Get-RandomCasing {
    [CmdletBinding()]
    [Alias('grc')]
    param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)][Alias('String', 'is', 's')][String]$InputString
    )
    BEGIN {
        [ScriptBlock]$randomBool = { [bool](Get-Random -Minimum 0 -Maximum 2) }
    }
    PROCESS {
        [string]$randomizedString = ""

        $charArray = $InputString.ToLower().ToCharArray()

        $sb = [System.Text.StringBuilder]::new()
        $charArray | ForEach-Object {
            if ($randomBool.Invoke()) {
                $sb.Append($_.ToString().ToUpper()) | Out-Null
            }
            else {
                $sb.Append($_.ToString()) | Out-Null
            }
        }
        $randomizedString = $sb.ToString()

        return $randomizedString
    }
}
