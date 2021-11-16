function Get-GraphQLVariableList {
    <#
        .SYNOPSIS
            Does a thing.
        .DESCRIPTION
            Does a thing with more detail.
    #>
    [CmdletBinding()]
    [Alias('ggqlvl')]
    [OutputType([GraphQLVariable], [System.Collections.Hashtable])]
    <##>
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)][ValidateLength(12, 1073741791)][Alias("Operation", "Mutation")][System.String]$Query,

        [Parameter(Mandatory = $false, Position = 1)][Switch]$AsHashtable
    )
    BEGIN {
        class GraphQLVariable {
            [string]$Operation
            [string]$Parameter
            [string]$Type
        }
    }
    PROCESS {
        # Exception to be used through the function in the case that an invalid GraphQL query or mutation is passed:
        $ArgumentException = New-Object -TypeName ArgumentException -ArgumentList "Not a valid GraphQL query or mutation. Verify syntax and try again."

        # Attempt to determine if value passed to the query parameter is an actual GraphQL query or mutation. If not, throw.
        [string]$trimmedQuery = $Query.Trim()

        if (($trimmedQuery -notlike "query*") -and ($trimmedQuery -notlike "mutation*") ) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # Get the first line of the incoming query or mutation as part of the process to determine the query or mutation name:
        $firstLine = $trimmedQuery -split "`r`n" | Select-Object -First 1

        # Determine query name by determining if query has parameters or not:
        [string]$queryName = ""
        [bool]$hasParameters = $false

        try {
            if (($firstLine -split " ")[1] -notmatch "\(") {
                $queryName = $firstLine.Split(" ")[1].Trim()
            }
            else {
                $queryName = $($firstLine.Split("(")[0].Split(" ")[1]).Trim()
                $hasParameters = $true
            }
        }
        catch {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # Just to be extra safe determine that the query name value ascertained from the above isn't an empty string:
        if ([string]::IsNullOrEmpty($queryName)) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }


        # List of objects that are returned by default:
        $results = [List[GraphQLVariable]]::new()

        if ($hasParameters) {
            # Run a regex against the first line looking for property name and type:
            [string]$queryNameAndTypeRegex = "(?<=\$)[_A-Za-z][_0-9A-Za-z]*:[\s]*[A-Za-z][0-9A-Za-z]*(?=[\!]?[,\)])"

            [regex]::Matches($firstLine, $queryNameAndTypeRegex) |
            Select-Object -ExpandProperty Value | ForEach-Object {
                $parameterName = ($_.Split(":")[0]).Trim()
                $parameterType = ($_.Split(":")[1]).Trim()

                $gqlVariable = [GraphQLVariable]::new()
                $gqlVariable.Operation = $queryName
                $gqlVariable.Parameter = $parameterName
                $gqlVariable.Type = $parameterType

                $results.Add($gqlVariable)
            }
        }
        else {
            $gqlVariable = [GraphQLVariable]::new()
            $gqlVariable.Operation = $queryName
            $results.Add($gqlVariable)
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
