#-------------------------------------------------- BEGIN Find-AdminSDHolder.ps1 --------------------------------------------------------------------
Import-Module -Name ActiveDirectory -ErrorAction Stop

$outputFilePath = "{0}_AdminSDHolders.csv" -f $env:USERDOMAIN

$domainDN = Get-ADDomain | Select-Object -Expand DistinguishedName

# ACLs we want to target..any one of these needs to be considered high risk!
$targetAdRightsToAudit = @("CreateChild", "DeleteChild", "WriteOwner", "WriteProperty", "WriteDacl")

# Get unique entry as key for hashtable and append rights:
$idMap = @{}
Get-Acl -Path "AD:\CN=AdminSDHolder,CN=System,$domainDN" | Select-Object -ExpandProperty Access | ForEach-Object {
    $adRights = $_.ActiveDirectoryRights -split ","

    $idRef = $_.IdentityReference

    if (-not($idMap.ContainsKey($idRef))) {
        $idMap.Add($idRef, $adRights)
    }
    else {
        $idMap[$idRef] += $adRights
    }
}

$groupMemberTable = @{}
Get-ADGroup -Filter * -Properties Member | ForEach-Object {
    $groupMemberTable.Add($_.Name, $_.Member)
}

# Class that will be used to represent the security principal and corresponding AD rights::
class IdentityAcl {
    [string]$SecurityPrincipal
    [string[]]$ActiveDirectoryRights
    [bool]$IsGroup
    [string[]]$GroupMembers

    IdentityAcl($prinName, $adRights, $isAdGroup, $memberDNs) {
        $this.SecurityPrincipal = $prinName
        $this.ActiveDirectoryRights = $adRights
        $this.IsGroup = $isAdGroup
        $this.GroupMembers = $memberDNs
    }
}

# Iterate through the hashtable populated prior, instantiate an IdentityAcl object
# with the identity as the SecurityPrincipal property and remove duplicate values for AD rights and
# assign to the ActiveDirectoryRights property:
$identityAcls = $idMap.GetEnumerator() | ForEach-Object {
    $idFullName = $_.Name.Value
    $idName = $idFullName.Replace(($env:USERDOMAIN + "\"), "")

    $adRights = ($_.Value | Select-Object -Unique).Trim()

    if ($groupMemberTable.ContainsKey($idName)) {
        $groupMemberDNs = $groupMemberTable[$idName]

        $groupMembers = @()
        $groupMemberDNs | ForEach-Object {
            $groupMembers += ($_.Split(",")[0].Replace("CN=", ""))
        }

        [IdentityAcl]::new($idFullName, $adRights, $true, $groupMembers)
    }
    else {
        [IdentityAcl]::new($idFullName, $adRights, $false, $null)
    }
}

# Using Compare-Object and Where-Object, determine if any of the AD rights on the incoming objects exist in the $targetAdRightsToAudit array:
$auditResults = $identityAcls | ForEach-Object {
    [int]$aclCount = Compare-Object -ReferenceObject $targetAdRightsToAudit -DifferenceObject $_.ActiveDirectoryRights -IncludeEqual |
        Where-Object SideIndicator -eq "==" | Measure-Object | Select-Object -ExpandProperty Count

    if ($aclCount -ge 1) {
        $ActiveDirectoryRights = @{Name = "ActiveDirectoryRights"; Expression = { $_.ActiveDirectoryRights -join ", " } }
        $GroupMembers = @{Name = "GroupMembers"; Expression = { $_.GroupMembers -join ", " } }
        $_ | Select-Object SecurityPrincipal, $ActiveDirectoryRights, IsGroup, $GroupMembers
    }
}

$auditResults | Export-Csv -Path $outputFilePath -NoTypeInformation
$auditResults | Out-GridView -Title ("AdminSDHolders for $env:USERDNSDOMAIN")
#---------------------------------------------------- END Find-AdminSDHolder.ps1 --------------------------------------------------------------------
