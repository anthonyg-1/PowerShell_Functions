#-------------------------------------------------- BEGIN Find-AdminSDHolder.ps1 --------------------------------------------------------------------
Import-Module -Name ActiveDirectory -ErrorAction Stop

$outputFilePath = "{0}_AdminSDHolders.csv" -f $env:USERDOMAIN

$domainDN = Get-ADDomain | Select-Object -Expand DistinguishedName

# ACLs we want to target..any one of these needs to be considered high risk!
$targetAdRightsToAudit = @("CreateChild", "DeleteChild", "WriteOwner", "WriteProperty", "WriteDacl", "GenericAll", "ExtendedRight")

$groupMemberTable = @{}
Get-ADGroup -Filter * -Properties Member | ForEach-Object {
    $groupMemberTable.Add($_.Name, $_.Member)
}

$ObjectTypeGUID = @{}

$GetADObjectParameter=@{
    SearchBase=(Get-ADRootDSE).SchemaNamingContext
    LDAPFilter='(SchemaIDGUID=*)'
    Properties=@("Name", "SchemaIDGUID")
}

Get-ADObject @GetADObjectParameter | ForEach-Object { $ObjectTypeGUID.Add(([GUID]$_.SchemaIDGUID),$_.Name) }


$ADObjExtPar=@{
    SearchBase="CN=Extended-Rights,$((Get-ADRootDSE).ConfigurationNamingContext)"
    LDAPFilter='(ObjectClass=ControlAccessRight)'
    Properties=@("Name", "RightsGUID")
}

Get-ADObject @ADObjExtPar |ForEach-Object { $ObjectTypeGUID.Add(([GUID]$_.RightsGUID),$_.Name) }


# Class that will be used to represent the security principal and corresponding AD rights::
class IdentityAcl {
    [string]$SecurityPrincipal
    [bool]$IsGroup
    [string]$GroupMembers
    [string]$ActiveDirectoryRights
    [string]$AttributeName
    [string]$InheritedObjectType
    [string]$InheritanceType

    IdentityAcl($prinName, $isAdGroup, $memberDNs, $adRights,$attributeName,$inheritedObjectType,$inheritanceType) {
        $this.SecurityPrincipal = $prinName
        $this.IsGroup = $isAdGroup
        $this.GroupMembers = $memberDNs
        $this.ActiveDirectoryRights = $adRights
        $this.AttributeName = $attributeName
        $this.InheritedObjectType = $inheritedObjectType
        $this.InheritanceType = $inheritanceType
    }
}

$adRightsLabel = @{Label="ADRights";Expression={$PSItem.ActiveDirectoryRights -Split ', '}}

$aclData = Get-Acl -Path "AD:\CN=AdminSDHolder,CN=System,$domainDN" | Select-Object -ExpandProperty Access

$auditResults = New-Object -TypeName System.Collections.Generic.List[IdentityAcl]

$aclData  | ForEach-Object {


    [string]$idFullName = $_.IdentityReference
    $idName = $idFullName.Replace(($env:USERDOMAIN + "\"), "")
    $idRefIsGroup = $groupMemberTable.ContainsKey($idName)

    $adRights = $_ | Select-Object -Property $adRightsLabel | Select-Object -ExpandProperty ADRights | Select-Object -Unique
    
    # Using Compare-Object and Where-Object, determine if any of the AD rights on the incoming objects exist in the $targetAdRightsToAudit array:
    [int]$aclCount = Compare-Object -ReferenceObject $targetAdRightsToAudit -DifferenceObject $adRights -IncludeEqual |
        Where-Object SideIndicator -eq "==" | Measure-Object | Select-Object -ExpandProperty Count

    if ($aclCount -ge 1) {

        If ($ObjectTypeGUID.ContainsKey($_.ObjectType))
        {
            $attributeName = $ObjectTypeGUID.Item($_.ObjectType)
        }
        Else
        {
            If ($_.ObjectType -eq '00000000-0000-0000-0000-000000000000')
            {
                $attributeName = 'All Properties'
            }
            Else
            {
                $attributeName = $_.ObjectType
            }
        }

        If ($ObjectTypeGUID.ContainsKey($_.InheritedObjectType))
        {
            $inheritedObjectType = $ObjectTypeGUID.Item($_.InheritedObjectType)
        }
        Else
        {
            If ($_.InheritedObjectType -eq '00000000-0000-0000-0000-000000000000')
            {
                $inheritedObjectType = 'This Object'
            }
            Else
            {
                $inheritedObjectType = $_.InheritedObjectType
            }
        }        

        if ($idRefIsGroup) {
            $groupMemberDNs = $groupMemberTable[$idName]

            $groupMembers = @()
            $groupMemberDNs | ForEach-Object {
                $groupMembers += ($_.Split(",")[0].Replace("CN=", ""))
            }
            $auditResults.add([IdentityAcl]::new($idFullName, $true, ($groupMembers -join ", "), $_.ActiveDirectoryRights,$attributeName,$inheritedObjectType,$_.InheritanceType))
        }
        else {
            $auditResults.add([IdentityAcl]::new($idFullName, $false, $null, $_.ActiveDirectoryRights,$attributeName,$inheritedObjectType,$_.InheritanceType))
        }

    }
}

$auditResults | Export-Csv -Path $outputFilePath -NoTypeInformation
$auditResults | Out-GridView -Title ("AdminSDHolders for $env:USERDNSDOMAIN")