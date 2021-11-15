function Get-GraphQLVariableList {
    [CmdletBinding()]
    [Alias('ggqlvc')]
    [OutputType([GraphQLVariable])]
    <##>
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)][ValidateLength(12, 1073741791)][Alias("Mutation", "q", "m")][System.String]$Query,

        [Parameter(Mandatory = $false, Position = 1)][Switch]$AsHashtable
    )
    BEGIN {
        class GraphQLVariable {
            [string]$Query = ""
            [string]$Parameter = ""
            [string]$Type = ""
        }
    }
    PROCESS {
        # Exception to be used through the function in the case that an invalid GraphQL query or mutation is passed:
        $ArgumentException = New-Object -TypeName ArgumentException -ArgumentList "Not a valid GraphQL query or mutation. Verify syntax and try again."

        # Attempt to determine if value passed to the query parameter is an actual GraphQL query or mutation. If not, throw.
        if (($Query.ToLower() -notlike "query*") -and ($Query.ToLower() -notlike "mutation*") ) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # Get the first line of the incoming query or mutation as part of the process to determine the query or mutation name:
        $firstLine = $Query -split "`r`n" | Select-Object -First 1

        # Determine query name by determining if query has parameters or not:
        [string]$queryName = ""
        try {
            if (($firstLine -split " ")[1] -notmatch "\(") {
                $queryName = $firstLine.Split(" ")[1].Trim()
            }
            else {
                $queryName = $firstLine.Split("\(").Split(" ")[1].Trim()
            }
        }
        catch {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # Just to be extra safe determine that the query name value ascertained from the above isn't an empty string:
        if ([string]::IsNullOrEmpty($queryName)) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # Two regexes; one to determine if parantheses exist, the other for non-alphanumeric.
        # Used in the following try block to put together results to be returned:
        $paranRegex = [RegEx]"\((.*)\)"
        $nonAlphaNumericRegex = [RegEx]"[^a-zA-Z0-9]"

        $results = [Collections.Generic.List[GraphQLVariable]]::new()
        try {
            $((([RegEx]::Match($firstLine, $paranRegex).Groups[1]).Value -split ",").Trim()) | ForEach-Object {
                $param = [RegEx]::Replace(($_.Split(":")[0].Trim()), $nonAlphaNumericRegex, "")
                $paramType = [RegEx]::Replace(($_.Split(":")[1].Trim()), $nonAlphaNumericRegex, "")

                $gqlvc = [GraphQLVariable]::new()
                $gqlvc.Query = $queryName
                $gqlvc.Parameter = $param
                $gqlvc.Type = $paramType
                $results.Add($gqlvc)
            }
        }
        catch {
            $gqlvc = [GraphQLVariable]::new()
            $gqlvc.Query = $queryName
            $results += $gqlvc
        }

        # Returns results as a hashtable with the key being the queryname
        # and a nested hashtable containing the query names and types as the value.
        # Else just returns the default collection of objects:
        if ($PSBoundParameters.ContainsKey("AsHashtable")) {
            $innerHashtable = @{ }
            $results | ForEach-Object {
                if (-not($innerHashtable.ContainsKey($_.Parameter))) {
                    $innerHashtable.Add($_.Parameter, $_.Type)
                }
            }

            $resultsHashtable = @{$queryName = $innerHashtable }

            return $resultsHashtable
        }
        else {
            return $results
        }
    }
}
