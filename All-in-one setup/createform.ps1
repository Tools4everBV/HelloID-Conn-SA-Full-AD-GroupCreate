#HelloID variables
$script:PortalBaseUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupNames = @("Users", "HID_administrators")
$delegatedFormCategories = @("Active Directory", "User Management")

# Create authorization headers with HelloID API key
$pair = "$apiKey" + ":" + "$apiSecret"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$key = "Basic $base64"
$script:headers = @{"authorization" = $Key}
# Define specific endpoint URI
$script:PortalBaseUrl = $script:PortalBaseUrl.trim("/") + "/"
 
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    
    if ($args) {
        Write-Output $args
    } else {
        $input | Write-Output
    }

    $host.UI.RawUI.ForegroundColor = $fc
}

function Invoke-HelloIDGlobalVariable {
    param(
        [parameter(Mandatory)][String]$Name,
        [parameter(Mandatory)][String][AllowEmptyString()]$Value,
        [parameter(Mandatory)][String]$Secret
    )

    try {
        $uri = ($script:PortalBaseUrl + "api/v1/automation/variables/named/$Name")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
    
        if ([string]::IsNullOrEmpty($response.automationVariableGuid)) {
            #Create Variable
            $body = @{
                name     = $Name;
                value    = $Value;
                secret   = $Secret;
                ItemType = 0;
            }    
            $body = $body | ConvertTo-Json
    
            $uri = ($script:PortalBaseUrl + "api/v1/automation/variable")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $variableGuid = $response.automationVariableGuid

            Write-ColorOutput Green "Variable '$Name' created: $variableGuid"
        } else {
            $variableGuid = $response.automationVariableGuid
            Write-ColorOutput Yellow "Variable '$Name' already exists: $variableGuid"
        }
    } catch {
        Write-ColorOutput Red "Variable '$Name', message: $_"
    }
}

function Invoke-HelloIDAutomationTask {
    param(
        [parameter(Mandatory)][String]$TaskName,
        [parameter(Mandatory)][String]$UseTemplate,
        [parameter(Mandatory)][String]$AutomationContainer,
        [parameter(Mandatory)][String][AllowEmptyString()]$Variables,
        [parameter(Mandatory)][String]$PowershellScript,
        [parameter()][String][AllowEmptyString()]$ObjectGuid,
        [parameter()][String][AllowEmptyString()]$ForceCreateTask,
        [parameter(Mandatory)][Ref]$returnObject
    )
    
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/automationtasks?search=$TaskName&container=$AutomationContainer")
        $responseRaw = (Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false) 
        $response = $responseRaw | Where-Object -filter {$_.name -eq $TaskName}
    
        if([string]::IsNullOrEmpty($response.automationTaskGuid) -or $ForceCreateTask -eq $true) {
            #Create Task

            $body = @{
                name                = $TaskName;
                useTemplate         = $UseTemplate;
                powerShellScript    = $PowershellScript;
                automationContainer = $AutomationContainer;
                objectGuid          = $ObjectGuid;
                variables           = [Object[]]($Variables | ConvertFrom-Json);
            }
            $body = $body | ConvertTo-Json
    
            $uri = ($script:PortalBaseUrl +"api/v1/automationtasks/powershell")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $taskGuid = $response.automationTaskGuid

            Write-ColorOutput Green "Powershell task '$TaskName' created: $taskGuid"  
        } else {
            #Get TaskGUID
            $taskGuid = $response.automationTaskGuid
            Write-ColorOutput Yellow "Powershell task '$TaskName' already exists: $taskGuid"
        }
    } catch {
        Write-ColorOutput Red "Powershell task '$TaskName', message: $_"
    }

    $returnObject.Value = $taskGuid
}

function Invoke-HelloIDDatasource {
    param(
        [parameter(Mandatory)][String]$DatasourceName,
        [parameter(Mandatory)][String]$DatasourceType,
        [parameter(Mandatory)][String][AllowEmptyString()]$DatasourceModel,
        [parameter()][String][AllowEmptyString()]$DatasourceStaticValue,
        [parameter()][String][AllowEmptyString()]$DatasourcePsScript,        
        [parameter()][String][AllowEmptyString()]$DatasourceInput,
        [parameter()][String][AllowEmptyString()]$AutomationTaskGuid,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $datasourceTypeName = switch($DatasourceType) { 
        "1" { "Native data source"; break} 
        "2" { "Static data source"; break} 
        "3" { "Task data source"; break} 
        "4" { "Powershell data source"; break}
    }
    
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/datasource/named/$DatasourceName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
      
        if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
            #Create DataSource
            $body = @{
                name               = $DatasourceName;
                type               = $DatasourceType;
                model              = [Object[]]($DatasourceModel | ConvertFrom-Json);
                automationTaskGUID = $AutomationTaskGuid;
                value              = [Object[]]($DatasourceStaticValue | ConvertFrom-Json);
                script             = $DatasourcePsScript;
                input              = [Object[]]($DatasourceInput | ConvertFrom-Json);
            }
            $body = $body | ConvertTo-Json
      
            $uri = ($script:PortalBaseUrl +"api/v1/datasource")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
              
            $datasourceGuid = $response.dataSourceGUID
            Write-ColorOutput Green "$datasourceTypeName '$DatasourceName' created: $datasourceGuid"
        } else {
            #Get DatasourceGUID
            $datasourceGuid = $response.dataSourceGUID
            Write-ColorOutput Yellow "$datasourceTypeName '$DatasourceName' already exists: $datasourceGuid"
        }
    } catch {
      Write-ColorOutput Red "$datasourceTypeName '$DatasourceName', message: $_"
    }

    $returnObject.Value = $datasourceGuid
}

function Invoke-HelloIDDynamicForm {
    param(
        [parameter(Mandatory)][String]$FormName,
        [parameter(Mandatory)][String]$FormSchema,
        [parameter(Mandatory)][Ref]$returnObject
    )
    
    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/forms/$FormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }
    
        if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true)) {
            #Create Dynamic form
            $body = @{
                Name       = $FormName;
                FormSchema = $FormSchema
            }
            $body = $body | ConvertTo-Json
    
            $uri = ($script:PortalBaseUrl +"api/v1/forms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
    
            $formGuid = $response.dynamicFormGUID
            Write-ColorOutput Green "Dynamic form '$formName' created: $formGuid"
        } else {
            $formGuid = $response.dynamicFormGUID
            Write-ColorOutput Yellow "Dynamic form '$FormName' already exists: $formGuid"
        }
    } catch {
        Write-ColorOutput Red "Dynamic form '$FormName', message: $_"
    }

    $returnObject.Value = $formGuid
}


function Invoke-HelloIDDelegatedForm {
    param(
        [parameter(Mandatory)][String]$DelegatedFormName,
        [parameter(Mandatory)][String]$DynamicFormGuid,
        [parameter()][String][AllowEmptyString()]$AccessGroups,
        [parameter()][String][AllowEmptyString()]$Categories,
        [parameter(Mandatory)][String]$UseFaIcon,
        [parameter()][String][AllowEmptyString()]$FaIcon,
        [parameter(Mandatory)][Ref]$returnObject
    )
    $delegatedFormCreated = $false
    
    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$DelegatedFormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }
    
        if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
            #Create DelegatedForm
            $body = @{
                name            = $DelegatedFormName;
                dynamicFormGUID = $DynamicFormGuid;
                isEnabled       = "True";
                accessGroups    = [Object[]]($AccessGroups | ConvertFrom-Json);
                useFaIcon       = $UseFaIcon;
                faIcon          = $FaIcon;
            }    
            $body = $body | ConvertTo-Json
    
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
    
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-ColorOutput Green "Delegated form '$DelegatedFormName' created: $delegatedFormGuid"
            $delegatedFormCreated = $true

            $bodyCategories = $Categories
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormGuid/categories")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $bodyCategories
            Write-ColorOutput Green "Delegated form '$DelegatedFormName' updated with categories"
        } else {
            #Get delegatedFormGUID
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-ColorOutput Yellow "Delegated form '$DelegatedFormName' already exists: $delegatedFormGuid"
        }
    } catch {
        Write-ColorOutput Red "Delegated form '$DelegatedFormName', message: $_"
    }

    $returnObject.value.guid = $delegatedFormGuid
    $returnObject.value.created = $delegatedFormCreated
}
<# Begin: HelloID Global Variables #>
$tmpValue = @'
OU=Groups,OU=HelloID Training,DC=veeken,DC=local
'@ 
Invoke-HelloIDGlobalVariable -Name "ADgroupsCreateOU" -Value $tmpValue -Secret "False" 
$tmpValue = @'
[{ "OU": "OU=Disabled Users,OU=HelloID Training,DC=veeken,DC=local"},{ "OU": "OU=Users,OU=HelloID Training,DC=veeken,DC=local"},{"OU": "OU=External,OU=HelloID Training,DC=veeken,DC=local"}]
'@ 
Invoke-HelloIDGlobalVariable -Name "ADusersSearchOU" -Value $tmpValue -Secret "False" 
<# End: HelloID Global Variables #>


<# Begin: HelloID Data sources #>
<# Begin: DataSource "AD-group-create-check-names" #>
$tmpPsScript = @'
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
'@ 
$tmpModel = @'
[{"key":"email","type":0},{"key":"name","type":0}]
'@ 
$tmpInput = @'
[{"description":null,"translateDescription":false,"inputFieldType":1,"key":"inputName","type":0,"options":1},{"description":null,"translateDescription":false,"inputFieldType":1,"key":"inputEmail","type":0,"options":0}]
'@ 
$dataSourceGuid_1 = [PSCustomObject]@{} 
Invoke-HelloIDDatasource -DatasourceName "AD-group-create-check-names" -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript -$tmpPsScript -DatasourceModel $tmpModel -returnObject ([Ref]$dataSourceGuid_1) 
<# End: DataSource "AD-group-create-check-names" #>

<# Begin: DataSource "AD-user-generate-table" #>
$tmpPsScript = @'
try {
    $searchOUs = $ADusersSearchOU
    Write-Information "SearchBase: $searchOUs"
        
    $ous = $searchOUs | ConvertFrom-Json
    $users = foreach($item in $ous) {
        Get-ADUser -Filter {Name -like "*"} -SearchBase $item.ou -properties SamAccountName, displayName, UserPrincipalName, Description, company, Department, Title
    }
        
    $users = $users | Sort-Object -Property DisplayName
    $resultCount = @($users).Count
    Write-Information "Result count: $resultCount"
        
    if($resultCount -gt 0){
        foreach($user in $users){
            $returnObject = @{SamAccountName=$user.SamAccountName; displayName=$user.displayName; UserPrincipalName=$user.UserPrincipalName; Description=$user.Description; Company=$user.company; Department=$user.Department; Title=$user.Title;}
            Write-Output $returnObject
        }
    }
} catch {
    $msg = "Error searching AD user [$searchValue]. Error: $($_.Exception.Message)"
    Write-Error $msg
}
'@ 
$tmpModel = @'
[{"key":"SamAccountName","type":0},{"key":"Title","type":0},{"key":"Description","type":0},{"key":"Company","type":0},{"key":"Department","type":0},{"key":"displayName","type":0},{"key":"UserPrincipalName","type":0}]
'@ 
$tmpInput = @'

'@ 
$dataSourceGuid_0 = [PSCustomObject]@{} 
Invoke-HelloIDDatasource -DatasourceName "AD-user-generate-table" -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript -$tmpPsScript -DatasourceModel $tmpModel -returnObject ([Ref]$dataSourceGuid_0) 
<# End: DataSource "AD-user-generate-table" #>
<# End: HelloID Data sources #>

<# Begin: Dynamic Form "AD Group - Create" #>
$tmpSchema = @"
[{"label":"Details","fields":[{"key":"name","templateOptions":{"label":"Name","required":true,"minLength":5,"pattern":"^[A-Za-z0-9._-]{6,50}$"},"validation":{"messages":{"pattern":"Allowed characters: a-z 0-9 . _ - \nMinimal 6, maximum 50 characters"}},"type":"input","summaryVisibility":"Hide element","requiresTemplateOptions":true},{"key":"description","templateOptions":{"label":"Description"},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true},{"key":"formRow","templateOptions":{},"fieldGroup":[{"key":"groupScope","templateOptions":{"label":"Group scope","useObjects":true,"options":[{"value":"DomainLocal","label":"Domain local"},{"value":"Global","label":"Global"},{"value":"Universal","label":"Universal"}],"required":true},"type":"radio","summaryVisibility":"Show","textOrLabel":"label","requiresTemplateOptions":true},{"key":"groupType","templateOptions":{"label":"Group type","useObjects":true,"options":[{"value":"Security","label":"Security"},{"value":"Distribution","label":"Distribution"}],"required":true},"type":"radio","summaryVisibility":"Show","textOrLabel":"label","requiresTemplateOptions":true}],"type":"formrow","requiresTemplateOptions":true},{"key":"email","templateOptions":{"label":"Email","pattern":"(?:[a-z0-9!#$%\u0026\u0027*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%\u0026\u0027*+/=?^_`{|}~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"},"validation":{"messages":{"pattern":"Invalid email address"}},"hideExpression":"model\[\\"groupType\\"]!==\u0027Distribution\u0027","type":"email","summaryVisibility":"Hide element","requiresTemplateOptions":true},{"key":"manager","templateOptions":{"label":"AD group manager","required":false,"grid":{"columns":[{"headerName":"DisplayName","field":"displayName"},{"headerName":"UserPrincipalName","field":"UserPrincipalName"},{"headerName":"Department","field":"Department"},{"headerName":"Title","field":"Title"},{"headerName":"Description","field":"Description"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_0","input":{"propertyInputs":[]}},"useFilter":true},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true}]},{"label":"Naming","fields":[{"key":"naming","templateOptions":{"label":"Naming convention","required":true,"grid":{"columns":[{"headerName":"Name","field":"name"},{"headerName":"Email","field":"email"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_1","input":{"propertyInputs":[{"propertyName":"inputName","otherFieldValue":{"otherFieldKey":"name"}},{"propertyName":"inputEmail","otherFieldValue":{"otherFieldKey":"email"}}]}},"useFilter":false},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true}]}]
"@ 

$dynamicFormGuid = [PSCustomObject]@{} 
Invoke-HelloIDDynamicForm -FormName "AD Group - Create" -FormSchema $tmpSchema  -returnObject ([Ref]$dynamicFormGuid) 
<# END: Dynamic Form #>

<# Begin: Delegated Form Access Groups and Categories #>
$delegatedFormAccessGroupGuids = @()
foreach($group in $delegatedFormAccessGroupNames) {
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/groups/$group")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        $delegatedFormAccessGroupGuid = $response.groupGuid
        $delegatedFormAccessGroupGuids += $delegatedFormAccessGroupGuid
        
        Write-ColorOutput Green "HelloID (access)group '$group' successfully found: $delegatedFormAccessGroupGuid"
    } catch {
        Write-ColorOutput Red "HelloID (access)group '$group', message: $_"
    }
}
$delegatedFormAccessGroupGuids = ($delegatedFormAccessGroupGuids | ConvertTo-Json -Compress)

$delegatedFormCategoryGuids = @()
foreach($category in $delegatedFormCategories) {
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories/$category")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid
        
        Write-ColorOutput Green "HelloID Delegated Form category '$category' successfully found: $tmpGuid"
    } catch {
        Write-ColorOutput Yellow "HelloID Delegated Form category '$category' not found"
        $body = @{
            name = @{"en" = $category};
        }
        $body = $body | ConvertTo-Json

        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid

        Write-ColorOutput Green "HelloID Delegated Form category '$category' successfully created: $tmpGuid"
    }
}
$delegatedFormCategoryGuids = ($delegatedFormCategoryGuids | ConvertTo-Json -Compress)
<# End: Delegated Form Access Groups and Categories #>

<# Begin: Delegated Form #>
$delegatedFormRef = [PSCustomObject]@{guid = $null; created = $null} 
Invoke-HelloIDDelegatedForm -DelegatedFormName "AD Group - Create" -DynamicFormGuid $dynamicFormGuid -AccessGroups $delegatedFormAccessGroupGuids -Categories $delegatedFormCategoryGuids -UseFaIcon "True" -FaIcon "fa fa-plus" -returnObject ([Ref]$delegatedFormRef) 
<# End: Delegated Form #>

<# Begin: Delegated Form Task #>
if($delegatedFormRef.created -eq $true) { 
	$tmpScript = @'
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
'@; 

	$tmpVariables = @'
[{"name":"description","value":"{{form.description}}","secret":false,"typeConstraint":"string"},{"name":"email","value":"{{form.naming.email}}","secret":false,"typeConstraint":"string"},{"name":"groupScope","value":"{{form.groupScope}}","secret":false,"typeConstraint":"string"},{"name":"groupType","value":"{{form.groupType}}","secret":false,"typeConstraint":"string"},{"name":"manager","value":"{{form.manager.UserPrincipalName}}","secret":false,"typeConstraint":"string"},{"name":"name","value":"{{form.naming.name}}","secret":false,"typeConstraint":"string"}]
'@ 

	$delegatedFormTaskGuid = [PSCustomObject]@{} 
	Invoke-HelloIDAutomationTask -TaskName "AD-group-create" -UseTemplate "False" -AutomationContainer "8" -Variables $tmpVariables -PowershellScript $tmpScript -ObjectGuid $delegatedFormRef.guid -ForceCreateTask $true -returnObject ([Ref]$delegatedFormTaskGuid) 
} else {
	Write-ColorOutput Yellow "Delegated form 'AD Group - Create' already exists. Nothing to do with the Delegated Form task..." 
}
<# End: Delegated Form Task #>
