function Get-GraphQLVariableCollection
{
    [CmdletBinding()]
    [Alias('ggqlvc')]
    [OutputType([GraphQLVariableCollection])]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]$Query
    )
    BEGIN
    {
        class GraphQLVariableCollection {
            [string]$Query = ""
            [string]$Parameter = ""
            [string]$Type = ""
        }
    }
    PROCESS
    {
        $results = @()

        if (($Query.ToLower() -notlike "query*") -and ($Query.ToLower() -notlike "mutation*") ) {
            $ArgumentException = New-Object -TypeName ArgumentException -ArgumentList "Not a valid GraphQL query or mutation. Verify syntax and try again."
            Write-Error -Exception $ArgumentException -Category InvalidArgument -ErrorAction Stop
        }

        $firstLine = $Query -split "`r`n" | Select-Object -First 1

        $paranRegex = [RegEx]"\((.*)\)"
        $queryRegex = [RegEx]"^.*\(\s*"
        $nonAlphaNumericRegex = [RegEx]"[^a-zA-Z0-9]"

        $queryName = ([RegEx]::Match($firstLine, $queryRegex).Groups[0].Value -replace "\(", "").Split(" ")[1]

        (([RegEx]::Match($firstLine, $paranRegex).Groups[1]).Value -split ",").Trim() | ForEach-Object {
             $param = [RegEx]::Replace(($_.Split(":")[0].Trim()), $nonAlphaNumericRegex, "")
             $paramType = [RegEx]::Replace(($_.Split(":")[1].Trim()), $nonAlphaNumericRegex, "")

             $gqlvc = [GraphQLVariableCollection]::new()
             $gqlvc.Query = $queryName
             $gqlvc.Parameter = $param
             $gqlvc.Type = $paramType

             $results += $gqlvc
        }

        return $results
    }
}
