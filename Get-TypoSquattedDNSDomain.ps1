function Get-TypoSquattedDNSDomain {
    <#
        .SYNOPSIS
            Generates typo-squatted DNS domain names based on common typos.

        .DESCRIPTION
            This function creates a list of typo-squatted domain names based on the provided domain name.
            It generates variations by omitting characters, doubling characters, swapping adjacent characters,
            and making adjacent key typos, while preserving the first character of the domain.
            It also appends or swaps additional DNS suffixes to increase the variety of results.

        .PARAMETER Domain
            The original domain name to base the typo-squatted domains on.

        .EXAMPLE
            PS> Get-TypoSquattedDNSDomain -Domain "example.com"

            This will generate typo-squatted domain names based on "example.com".

        .INPUTS
            String

        .OUTPUTS
            String
    #>
    [CmdletBinding()]
    [Alias('gtsd')]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)][ValidateLength(1, 255)][Alias('d')][System.String]$Domain
    )
    Begin {
        # Define a simple keyboard layout to simulate adjacent key errors
        $keyboardLayout = @{
            'q' = 'w'; 'w' = 'qe'; 'e' = 'wr'; 'r' = 'et'; 't' = 'ry'; 'y' = 'tu'; 'u' = 'yi'; 'i' = 'uo'; 'o' = 'ip'; 'p' = 'o';
            'a' = 's'; 's' = 'ad'; 'd' = 'sf'; 'f' = 'dg'; 'g' = 'fh'; 'h' = 'gj'; 'j' = 'hk'; 'k' = 'jl'; 'l' = 'k';
            'z' = 'x'; 'x' = 'zc'; 'c' = 'xv'; 'v' = 'cb'; 'b' = 'vn'; 'n' = 'bm'; 'm' = 'n';
        }

        $domainSuffixes = @('biz', 'co', 'com', 'info', 'net', 'org', 'site', 'us')

        # Helper function to get adjacent key typos:
        function Get-AdjacentKeyTypo {
            param ([string]$char)
            if ($keyboardLayout.ContainsKey($char)) {
                return $keyboardLayout[$char].ToCharArray()
            }
            return @()
        }

        # Helper function to swap characters in a string:
        function Invoke-CharacterSwap {
            param ([char[]]$charArray, [int]$pos1, [int]$pos2)
            $tmp = $charArray[$pos1]
            $charArray[$pos1] = $charArray[$pos2]
            $charArray[$pos2] = $tmp
            return $charArray
        }

        function Get-HyphenatedDomainList {
            Param (
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)][ValidateLength(1, 255)][System.String]$domain
            )
            Process {
                [string[]]$hyphenatedDomains = @()

                $fullDomain = $domain

                # Find the last index of the period character
                $lastPeriodIndex = $fullDomain.LastIndexOf('.')

                # Get the substring before the last period (second-level domain)
                $secondLevelDomain = $fullDomain.Substring(0, $lastPeriodIndex)
                $secondLastPeriodIndex = $secondLevelDomain.LastIndexOf('.')

                # Get the base domain (part after the second last period)
                $baseDomain = $secondLevelDomain.Substring($secondLastPeriodIndex + 1) + $fullDomain.Substring($lastPeriodIndex)

                foreach ($domainSuffix in $domainSuffixes) {
                    $hyphenatedDomains += ($baseDomain.Replace(".", "-") + "." + $domainSuffix)
                }

                return $hyphenatedDomains
            }
        }

        # Helper function to generate common typo squatted domains including hyphenated domains
        function New-TypoDomain {
            param ([string]$domain, [string]$originalSuffix, [string[]]$suffixes)

            $typoDomains = @()

            # Split the domain to get each part except the TLD
            $domainParts = $domain -split '\.'
            $domainWithoutTLD = $domainParts[0..($domainParts.Count - 2)]

            foreach ($part in $domainWithoutTLD) {
                for ($i = 0; $i -lt $part.Length; $i++) {
                    # Character omission (not in the first character)
                    if ($i -gt 0) {
                        $typoDomains += ($part.Remove($i, 1) -join ".") + ".$originalSuffix"
                    }

                    # Character doubling
                    $typoDomains += ($part.Insert($i, $part[$i]) -join ".") + ".$originalSuffix"

                    # Character swapping with next
                    if ($i -lt $part.Length - 1) {
                        $charArray = $part.ToCharArray()
                        $charArray = Invoke-CharacterSwap -CharArray $charArray -Pos1 $i -Pos2 ($i + 1)
                        $typoDomains += (-join $charArray -join ".") + ".$originalSuffix"
                    }

                    # Adjacent key errors
                    foreach ($adjacentChar in Get-AdjacentKeyTypo($part[$i])) {
                        $typoResult = ($part.Remove($i, 1).Insert($i, $adjacentChar) -join ".") + ".$originalSuffix"
                        $typoDomains += $typoResult
                    }
                }
            }

            # Append original suffix and generate hyphenated domains
            $typoDomains = $typoDomains | ForEach-Object {
                $alteredDomain = $_
                $hyphenatedDomain = ($_ -replace '\.', '-') + '.' + ($suffixes | Get-Random)
                @($alteredDomain, $hyphenatedDomain)
            }

            return $typoDomains | Sort-Object -Unique
        }
    }
    Process {
        [string[]]$typoDomains = @()

        $targetDomain = $Domain

        # Extract the base domain name and the suffix
        $domainParts = $targetDomain -split '\.'
        $baseDomain = $domainParts[0]
        $originalSuffix = $domainParts[1]

        # Generate a variety of typo domains
        $typicalTypoSquattedDomains = New-TypoDomain -Domain $baseDomain -OriginalSuffix $originalSuffix -Suffixes $domainSuffixes
        $typoDomains += $typicalTypoSquattedDomains
        $typoDomains += (Get-HyphenatedDomainList -domain $targetDomain)

        # Output results
        $typoDomains | Sort-Object -Unique
    }
}
