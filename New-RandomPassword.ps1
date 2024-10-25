function New-RandomPassword {
    [CmdletBinding()]
    [Alias('nrp')]
    [OutputType([string], [void])]
    param
    (
        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)][Alias('l')][int]$Length = 24,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)][Alias('c', 'clip')][Switch]$ToClipboard

    )
    PROCESS {
        $nonAlphaNumericCharacters = '!@#$%^&*'
        $alphaNumericCharacters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

        $allowedCharacters += ($nonAlphaNumericCharacters, $alphaNumericCharacters)

        # Starting in PowerShell 5, Get-Random uses RNGCryptoServiceProvider. See: https://www.sans.org/blog/truerng-random-numbers-with-powershell-and-math-net-numerics/
        $randomPasswordString = ($allowedCharacters.ToCharArray() |
            Sort-Object -Property { Get-Random })[1..$Length] -join ''

        if ($PSBoundParameters.ContainsKey("ToClipboard")) {
            $randomPasswordString | Set-Clipboard

            Write-Warning -Message 'Newly generated password sent to the clipboard. Clear clipboard contents by running the following: scb $null'
        }
        else {
            return $randomPasswordString
        }
    }
}
