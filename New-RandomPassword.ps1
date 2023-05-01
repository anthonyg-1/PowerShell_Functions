function New-RandomPassword ([int]$Length = 24) {
    $nonAlphaNumericCharacters = '!@#$%^&*'
    $alphaNumericCharacters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

    $allowedCharacters += ($nonAlphaNumericCharacters, $alphaNumericCharacters)

    # Starting in PowerShell 5, Get-Random uses RNGCryptoServiceProvider. See: https://www.sans.org/blog/truerng-random-numbers-with-powershell-and-math-net-numerics/
    $randomPasswordString = ($allowedCharacters.ToCharArray() |
        Sort-Object -Property { Get-Random })[1..$Length] -join ''

    return $randomPasswordString
}
