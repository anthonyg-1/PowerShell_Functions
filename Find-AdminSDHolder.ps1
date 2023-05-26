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

#Query Schema for object types and their GUIDs
$ObjectTypeGUID = @{}
$GetADObjectParameter=@{
    SearchBase=(Get-ADRootDSE).SchemaNamingContext
    LDAPFilter='(SchemaIDGUID=*)'
    Properties=@("Name", "SchemaIDGUID")
}
Get-ADObject @GetADObjectParameter | ForEach-Object { 
    If (! $ObjectTypeGUID.ContainsKey(([GUID]$_.SchemaIDGUID)))
    {
        $ObjectTypeGUID.Add(([GUID]$_.SchemaIDGUID),$_.Name) 
    }  
}

$ADObjExtPar=@{
    SearchBase="CN=Extended-Rights,$((Get-ADRootDSE).ConfigurationNamingContext)"
    LDAPFilter='(ObjectClass=ControlAccessRight)'
    Properties=@("Name", "RightsGUID")
}

Get-ADObject @ADObjExtPar |ForEach-Object { 
    If (! $ObjectTypeGUID.ContainsKey(([GUID]$_.RightsGUID)))
    {
        $ObjectTypeGUID.Add(([GUID]$_.RightsGUID),$_.Name) 
    }
}


# Class that will be used to represent the security principal and corresponding AD rights::
class IdentityAcl {
    [string]$SecurityPrincipal
    [bool]$IsGroup
    [string]$GroupMembers
    [string]$ActiveDirectoryRights
    [string]$InheritedObjectType
    [string]$InheritanceType
    [string]$AttributeName

    IdentityAcl($prinName, $isAdGroup, $memberDNs, $adRights,$inheritedObjectType,$inheritanceType,$attributeName) {
        $this.SecurityPrincipal = $prinName
        $this.IsGroup = $isAdGroup
        $this.GroupMembers = $memberDNs
        $this.ActiveDirectoryRights = $adRights
        $this.InheritedObjectType = $inheritedObjectType
        $this.InheritanceType = $inheritanceType
        $this.AttributeName = $attributeName
    }
}

$adRightsLabel = @{Label="ADRights";Expression={$PSItem.ActiveDirectoryRights -Split ', '}}
$adRightsUIDLabel = @{Label="ADRightsUID";Expression={"{0}-{1}-{2}-{3}" -f $PSItem.IdentityReference,$PSItem.ActiveDirectoryRights, $PSItem.InheritedObjectType, $PSItem.InheritanceType}}

$aclData = Get-Acl -Path "AD:\CN=AdminSDHolder,CN=System,$domainDN" | Select-Object -ExpandProperty Access | Select-Object -Property *, $adRightsLabel, $adRightsUIDLabel

$auditResults = New-Object -TypeName System.Collections.Generic.List[IdentityAcl]

$aclData | Group-Object -Property ADRightsUID | ForEach-Object {

    $firstACE = $_.Group[0]
    [string]$idFullName = $firstACE.IdentityReference
    $idName = $idFullName.Replace(($env:USERDOMAIN + "\"), "")
    $idRefIsGroup = $groupMemberTable.ContainsKey($idName)

    $adRights = $_.Group | Select-Object -ExpandProperty ADRights | Select-Object -Unique
    
    # Using Compare-Object and Where-Object, determine if any of the AD rights on the incoming objects exist in the $targetAdRightsToAudit array:
    [int]$aclCount = Compare-Object -ReferenceObject $targetAdRightsToAudit -DifferenceObject $adRights -IncludeEqual |
        Where-Object SideIndicator -eq "==" | Measure-Object | Select-Object -ExpandProperty Count

    if ($aclCount -ge 1) {
        $attributeNameList = $_.Group | ForEach-Object {
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
            Write-Output $attributeName
        }

        If ($ObjectTypeGUID.ContainsKey($firstACE.InheritedObjectType))
        {
            $inheritedObjectType = $ObjectTypeGUID.Item($firstACE.InheritedObjectType)
        }
        Else
        {
            If ($firstACE.InheritedObjectType -eq '00000000-0000-0000-0000-000000000000')
            {
                $inheritedObjectType = 'This Object'
            }
            Else
            {
                $inheritedObjectType = $firstACE.InheritedObjectType
            }
        }        

        $flattenedAttributes = $attributeNameList -join ', '

        if ($idRefIsGroup) {
            $groupMemberDNs = $groupMemberTable[$idName]

            $groupMembers = @()
            $groupMemberDNs | ForEach-Object {
                $groupMembers += ($_.Split(",")[0].Replace("CN=", ""))
            }
            $auditResults.add([IdentityAcl]::new($idFullName, $true, ($groupMembers -join ", "), $firstACE.ActiveDirectoryRights,$inheritedObjectType,$firstACE.InheritanceType,$flattenedAttributes))
        }
        else {
            $auditResults.add([IdentityAcl]::new($idFullName, $false, $null, $firstACE.ActiveDirectoryRights,$inheritedObjectType,$firstACE.InheritanceType,$flattenedAttributes))
        }

    }
}

$auditResults | Export-Csv -Path $outputFilePath -NoTypeInformation
$auditResults | Out-GridView -Title ("AdminSDHolders for $env:USERDNSDOMAIN")