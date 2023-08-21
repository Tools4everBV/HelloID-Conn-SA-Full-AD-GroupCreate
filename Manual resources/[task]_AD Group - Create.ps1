$description = $form.description
$email = $form.naming.email
$groupScope = $form.groupScope
$groupType = $form.groupType
$manager = $form.manager.UserPrincipalName
$name = $form.naming.name

try {
    $ADGroupParams = @{
        Name           = $name
        DisplayName    = $name
        SamAccountName = $name
        GroupCategory  = $groupType 
        GroupScope     = $groupScope
        Description    = $description
        Path           = $ADgroupsCreateOU
    }
    
    if($manager -ne "") {
        $managerObject = Get-ADuser -Filter { UserPrincipalName -eq $manager }
        $ADGroupParams.Add( 'managedBy', $managerObject )
    }
    
    if($email -ne "") {
        $ADGroupParams.Add( 'OtherAttributes', @{mail="$email"} )
    }
    
    New-ADGroup @ADGroupParams
    
    Write-Information "AD group [$name] created successfully"
    $Log = @{
            Action            = "CreateResource" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = "AD group [$name] created successfully" # required (free format text) 
            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $name # optional (free format text) 
            TargetIdentifier  = $name # optional (free format text) 
        }
        #send result back  
    Write-Information -Tags "Audit" -MessageData $log

} catch {
    Write-Error "Error creating AD group [$name]. Error: $($_.Exception.Message)" 
    $Log = @{
            Action            = "CreateResource" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = "Error creating AD group [$name]. Error: $($_.Exception.Message)" # required (free format text) 
            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $name # optional (free format text) 
            TargetIdentifier  = $name # optional (free format text) 
        }
        #send result back  
    Write-Information -Tags "Audit" -MessageData $log
}
