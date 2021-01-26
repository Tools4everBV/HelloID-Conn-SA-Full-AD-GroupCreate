try {
    $searchOUs = $ADusersSearchOU
    $groupName = $datasource.selectedGroup.Name
    
    $currentManager = ""    
    if([String]::IsNullOrEmpty($groupName) -eq $false){
        $selectedGroup = Get-ADgroup -Filter { Name -eq $groupName } -Properties managedBy
        $currentManager = $selectedGroup.managedBy
    }

    Write-Information "SearchBase: $searchOUs"
        
    $ous = $searchOUs | ConvertFrom-Json
    $users = foreach($item in $ous) {
        Get-ADUser -Filter {Name -like "*"} -SearchBase $item.ou -properties DistinguishedName, SamAccountName, displayName, UserPrincipalName, Description, company, Department, Title
    }
        
    $users = $users | Sort-Object -Property DisplayName
    $resultCount = @($users).Count
    Write-Information "Result count: $resultCount"
        
    if($resultCount -gt 0){
        foreach($user in $users){
            $returnObject = @{SamAccountName=$user.SamAccountName; displayName=$user.displayName; UserPrincipalName=$user.UserPrincipalName; Description=$user.Description; Company=$user.company; Department=$user.Department; Title=$user.Title; selected = ($user.DistinguishedName -eq $currentManager)}
            Write-Output $returnObject
        }
    }
} catch {
    $msg = "Error searching AD user [$searchValue]. Error: $($_.Exception.Message)"
    Write-Error $msg
}
