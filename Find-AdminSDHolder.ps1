#--------------------------------------------------BEGIN Find-AdminSDHolder.ps1--------------------------------------------------------------------
Import-Module -Name ActiveDirectory -ErrorAction Stop

$domainDN = Get-ADDomain | Select-Object -Expand DistinguishedName

# ACLs we want to target..any one of these needs to be considered high risk!
$targetAdRightsToAudit = @("CreateChild", "DeleteChild", "WriteOwner", "WriteProperty", "WriteDacl")

# Get unique entry as key for hashtable and append rights:
$idMap = @{}
Get-Acl -Path "AD:\CN=AdminSDHolder,CN=System,$domainDN" | Select-Object -ExpandProperty Access | ForEach-Object {
    $adRights = $_.ActiveDirectoryRights -split ","

    $idRef = $_.IdentityReference

    if (-not($idMap.Contains($idRef))) {
        $idMap.Add($idRef, $adRights)
    }
    else {
        $idMap[$idRef] += $adRights
    }
}

# Class that will be used to represent the security principal and corresponding AD rights::
class IdentityAcl {
    [string]$SecurityPrincipal
    [string[]]$ActiveDirectoryRights

    IdentityAcl($prinName, $adRights) {
        $this.SecurityPrincipal = $prinName
        $this.ActiveDirectoryRights = $adRights
    }
}

# Iterate through the hashtable populated prior, instantiate an IdentityAcl object
# with the identity as the SecurityPrincipal property and remove duplicate values for AD rights and
# assign to the ActiveDirectoryRights property:
$identityAcls = $idMap.GetEnumerator() | ForEach-Object {
    [IdentityAcl]::new($_.Name.Value, ($_.Value | Select-Object -Unique).Trim())
}

# Using Compare-Object and Where-Object, determine if any of the AD rights on the incoming objects exist in the $targetAdRightsToAudit array:
$auditResults = $identityAcls | ForEach-Object {
    [int]$aclCount = Compare-Object -ReferenceObject $targetAdRightsToAudit -DifferenceObject $_.ActiveDirectoryRights -IncludeEqual |
        Where-Object SideIndicator -eq "==" | Measure-Object | Select-Object -ExpandProperty Count

    if ($aclCount -ge 1) {
        $_
    }
}

$auditResults | Out-GridView -Title ("AdminSDHolders for $env:USERDNSDOMAIN")
#----------------------------------------------------END Find-AdminSDHolder.ps1--------------------------------------------------------------------
