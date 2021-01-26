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
    
    Hid-Write-Status -Message "AD group [$name] created successfully" -Event Success
    HID-Write-Summary -Message "AD group [$name] created successfully" -Event Success
} catch {
    HID-Write-Status -Message "Error creating AD group [$name]. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Error creating AD group [$name]" -Event Failed
}
