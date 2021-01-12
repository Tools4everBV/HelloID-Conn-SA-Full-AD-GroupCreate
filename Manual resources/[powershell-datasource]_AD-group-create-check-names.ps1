$returnName = ""
$returnEmail = ""

try {
	$iterationMax = 10
	$name = $datasource.inputName
	$email = $datasource.inputEmail
	
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
		
		Write-information "Searching for AD group [$searchName]"
		$foundName = Get-ADGroup -Filter{Name -eq $searchName}


		if(@($foundName).count -eq 0) {
			$returnName = $searchName

			Write-information "AD group [$searchName] not found"
			break;
		} else {
			Write-information "AD group [$searchName] found"
		}
	}

	if(-not ([string]::IsNullOrEmpty($email))) {
		for($i = 0; $i -lt $iterationMax; $i++) {
			
			if($i -eq 0) {
				$searchEmail = $mailPrefix + "@" + $mailSuffix
			} else {
				$searchEmail = $mailPrefix + "$i@" + $mailSuffix
			}
			
			Write-information "Searching for AD group with email [$searchEmail]"
			$foundEmail = Get-ADGroup -Filter{mail -eq $searchEmail}

			if(@($foundEmail).count -eq 0) {
				$returnEmail = $searchEmail

				Write-information "AD group with email [$searchEmail] not found"
				break;
			} else {
				Write-information "AD group with email [$searchEmail] found"
			}
		}
	}
} catch {
    Write-error "Error generating names. Error: $($_.Exception.Message)"
}

Write-output @{name=$returnName;email=$returnEmail}
