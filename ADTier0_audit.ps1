# Ensure the Active Directory module is loaded
Import-Module ActiveDirectory

function Get-GroupMembers {
    param (
        [string]$GroupName,
        [string]$Domain
    )
    
    # Attempt to retrieve group members
    try {
        $groupMembers = Get-ADGroupMember -Identity "$GroupName" -Server $Domain -Recursive | Select-Object Name, ObjectClass, DistinguishedName
        return $groupMembers
    } catch {
        Write-Warning "Could not retrieve members of $GroupName for domain $Domain. Error: $_"
        return $null
    }
}

# Retrieve all trusted domains
$trustedDomains = Get-ADTrust

foreach ($domain in $trustedDomains) {
    $domainName = $domain.Name

    Write-Host "Processing domain: $domainName"

    # Get members of Domain Admins
    $domainAdmins = Get-GroupMembers -GroupName "Domain Admins" -Domain $domainName
    Write-Host "Domain Admins for $domainName:"
    $domainAdmins | Format-Table -Property Name, ObjectClass, DistinguishedName

    # Get members of Administrators
    $administrators = Get-GroupMembers -GroupName "Administrators" -Domain $domainName
    Write-Host "Administrators for $domainName:"
    $administrators | Format-Table -Property Name, ObjectClass, DistinguishedName
}

# Get members of Enterprise Admins for the forest
$enterpriseAdmins = Get-GroupMembers -GroupName "Enterprise Admins" -Domain (Get-ADForest).RootDomain
Write-Host "Enterprise Admins for the forest:"
$enterpriseAdmins | Format-Table -Property Name, ObjectClass, DistinguishedName
