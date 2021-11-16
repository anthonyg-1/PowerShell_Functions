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

        # Compress and trim the incoming query for all operations within this function:
        [string]$cleanedQueryInput = Compress-String -InputString $Query

        # Attempt to determine if value passed to the query parameter is an actual GraphQL query or mutation. If not, throw:
        if (($cleanedQueryInput -notlike "query*") -and ($cleanedQueryInput -notlike "mutation*") ) {
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        # Get the query name via regex and splitting on the first space after query or mutation:
        $matchOnParanOrCurlyRegex = '^[^\(|{]+'
        $operationName = [regex]::Match(($cleanedQueryInput.Split(" ")[1]), $matchOnParanOrCurlyRegex) | Select-Object -ExpandProperty Value

        # List of objects that are returned by default:
        $results = [List[GraphQLVariable]]::new()

        # Run a regex against the incoming query looking for property name and type:
        [string]$queryNameAndTypeRegex = "(?<=\$)[_A-Za-z][_0-9A-Za-z]*:[\s]*[A-Za-z][0-9A-Za-z]*(?=[\!]?[,\)])"
        $possibleMatches = [regex]::Matches($cleanedQueryInput, $queryNameAndTypeRegex)

        # If we get matches, add to results list. Else, return a single object in the list containing the operation name only:
        if ($possibleMatches.Count -gt 0) {
            $possibleMatches | Select-Object -ExpandProperty Value | ForEach-Object {
                $parameterName = ($_.Split(":")[0]).Trim()
                $parameterType = ($_.Split(":")[1]).Trim()

                $gqlVariable = [GraphQLVariable]::new()
                $gqlVariable.Operation = $operationName
                $gqlVariable.Parameter = $parameterName
                $gqlVariable.Type = $parameterType

                $results.Add($gqlVariable)
            }
        }
        else {
            $gqlVariable = [GraphQLVariable]::new()
            $gqlVariable.Operation = $operationName
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
