function Get-GraphQLVariableCollection {
    [CmdletBinding()]
    [Alias('ggqlvc')]
    [OutputType([GraphQLVariableCollection])]
    Param
    (
        [Parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            Position = 0)][ValidateLength(12, 1073741791)][Alias("Mutation", "q", "m")][System.String]$Query
    )
    BEGIN {
        class GraphQLVariableCollection {
            [string]$Query = ""
            [string]$Parameter = ""
            [string]$Type = ""
        }
    }
    PROCESS {
        $results = @()

        if (($Query.ToLower() -notlike "query*") -and ($Query.ToLower() -notlike "mutation*") ) {
            $ArgumentException = New-Object -TypeName ArgumentException -ArgumentList "Not a valid GraphQL query or mutation. Verify syntax and try again."
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        $firstLine = $Query -split "`r`n" | Select-Object -First 1

        # Determine query name by determining if query has parameters or not:
        [string]$queryName = ""
        if (($firstLine -split " ")[1] -notmatch "\(") {
            $queryName = $firstLine.Split(" ")[1].Trim()
        }
        else {
            $queryName = $firstLine.Split("\(").Split(" ")[1].Trim()
        }

        $paranRegex = [RegEx]"\((.*)\)"
        $nonAlphaNumericRegex = [RegEx]"[^a-zA-Z0-9]"

        try {
            $((([RegEx]::Match($firstLine, $paranRegex).Groups[1]).Value -split ",").Trim()) | ForEach-Object {
                $param = [RegEx]::Replace(($_.Split(":")[0].Trim()), $nonAlphaNumericRegex, "")
                $paramType = [RegEx]::Replace(($_.Split(":")[1].Trim()), $nonAlphaNumericRegex, "")

                $gqlvc = [GraphQLVariableCollection]::new()
                $gqlvc.Query = $queryName
                $gqlvc.Parameter = $param
                $gqlvc.Type = $paramType
                $results += $gqlvc
            }
        }
        catch {
            $gqlvc = [GraphQLVariableCollection]::new()
            $gqlvc.Query = $queryName
            $results += $gqlvc
        }

        return $results
    }
}
