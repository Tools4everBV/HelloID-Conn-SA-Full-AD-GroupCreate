$returnName = ""
$returnEmail = ""
 
try {
    $iterationMax = 10
    $name = $formInput.inputName
    $email = $formInput.inputEmail
     
    if(-not ([string]::IsNullOrEmpty($email))) {
        $emailSplit = $email.split("@")
        $mailPrefix = $emailSplit[0]
        $mailSuffix = $emailSplit[1]
    }
 
 
    function Remove-StringLatinCharacters
    {
        PARAM ([string]$String)
        [Text.Encoding]::ASCII.GetString([Text.Encoding]::GetEncoding("Cyrillic").GetBytes($String))
    }
      
    $name = Remove-StringLatinCharacters $name
    $name = $name.trim() -replace '\s+', ' '
 
 
    for($i = 0; $i -lt $iterationMax; $i++) {
         
        if($i -eq 0) {
            $searchName = $name
        } else {
            $searchName = $name + "_$i"
        }
         
        Hid-Write-Status -Message "Searching for AD group [$searchName]" -Event Information
        $foundName = Get-ADGroup -Filter{Name -eq $searchName}
 
 
        if(@($foundName).count -eq 0) {
            $returnName = $searchName
 
            Hid-Write-Status -Message "AD group [$searchName] not found" -Event Information
            break;
        } else {
            Hid-Write-Status -Message "AD group [$searchName] found" -Event Information
        }
    }
 
    if(-not ([string]::IsNullOrEmpty($email))) {
        for($i = 0; $i -lt $iterationMax; $i++) {
             
            if($i -eq 0) {
                $searchEmail = $mailPrefix + "@" + $mailSuffix
            } else {
                $searchEmail = $mailPrefix + "$i@" + $mailSuffix
            }
             
            Hid-Write-Status -Message "Searching for AD group with email [$searchEmail]" -Event Information
            $foundEmail = Get-ADGroup -Filter{mail -eq $searchEmail}
 
            if(@($foundEmail).count -eq 0) {
                $returnEmail = $searchEmail
 
                Hid-Write-Status -Message "AD group with email [$searchEmail] not found" -Event Information
                break;
            } else {
                Hid-Write-Status -Message "AD group with email [$searchEmail] found" -Event Information
            }
        }
    }
} catch {
    HID-Write-Status -Message "Error generating names. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Error generating names" -Event Failed
}
 
Hid-Add-TaskResult -ResultValue @{name=$returnName;email=$returnEmail}