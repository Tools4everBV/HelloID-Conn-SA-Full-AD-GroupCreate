# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
#HelloID variables
#Note: when running this script inside HelloID; portalUrl and API credentials are provided automatically (generate and save API credentials first in your admin panel!)
$portalUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupNames = @("") #Only unique names are supported. Groups must exist!
$delegatedFormCategories = @("User Management","Active Directory") #Only unique names are supported. Categories will be created if not exists
$script:debugLogging = $false #Default value: $false. If $true, the HelloID resource GUIDs will be shown in the logging
$script:duplicateForm = $false #Default value: $false. If $true, the HelloID resource names will be changed to import a duplicate Form
$script:duplicateFormSuffix = "_tmp" #the suffix will be added to all HelloID resource names to generate a duplicate form with different resource names

#The following HelloID Global variables are used by this form. No existing HelloID global variables will be overriden only new ones are created.
#NOTE: You can also update the HelloID Global variable values afterwards in the HelloID Admin Portal: https://<CUSTOMER>.helloid.com/admin/variablelibrary
$globalHelloIDVariables = [System.Collections.Generic.List[object]]@();

#Global variable #1 >> ADgroupsCreateOU
$tmpName = @'
ADgroupsCreateOU
'@ 
$tmpValue = @'
OU=Groups,OU=HelloID Training,DC=veeken,DC=local
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});

#Global variable #2 >> ADusersSearchOU
$tmpName = @'
ADusersSearchOU
'@ 
$tmpValue = @'
[{ "OU": "DC=corporate,DC=local"}]
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});


#make sure write-information logging is visual
$InformationPreference = "continue"
# Check for prefilled API Authorization header
if (-not [string]::IsNullOrEmpty($portalApiBasic)) {
    $script:headers = @{"authorization" = $portalApiBasic}
    Write-Information "Using prefilled API credentials"
} else {
    # Create authorization headers with HelloID API key
    $pair = "$apiKey" + ":" + "$apiSecret"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"
    $script:headers = @{"authorization" = $Key}
    Write-Information "Using manual API credentials"
}
# Check for prefilled PortalBaseURL
if (-not [string]::IsNullOrEmpty($portalBaseUrl)) {
    $script:PortalBaseUrl = $portalBaseUrl
    Write-Information "Using prefilled PortalURL: $script:PortalBaseUrl"
} else {
    $script:PortalBaseUrl = $portalUrl
    Write-Information "Using manual PortalURL: $script:PortalBaseUrl"
}
# Define specific endpoint URI
$script:PortalBaseUrl = $script:PortalBaseUrl.trim("/") + "/"  
# Make sure to reveive an empty array using PowerShell Core
function ConvertFrom-Json-WithEmptyArray([string]$jsonString) {
    # Running in PowerShell Core?
    if($IsCoreCLR -eq $true){
        $r = [Object[]]($jsonString | ConvertFrom-Json -NoEnumerate)
        return ,$r  # Force return value to be an array using a comma
    } else {
        $r = [Object[]]($jsonString | ConvertFrom-Json)
        return ,$r  # Force return value to be an array using a comma
    }
}
function Invoke-HelloIDGlobalVariable {
    param(
        [parameter(Mandatory)][String]$Name,
        [parameter(Mandatory)][String][AllowEmptyString()]$Value,
        [parameter(Mandatory)][String]$Secret
    )
    $Name = $Name + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })
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
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl + "api/v1/automation/variable")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $variableGuid = $response.automationVariableGuid
            Write-Information "Variable '$Name' created$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        } else {
            $variableGuid = $response.automationVariableGuid
            Write-Warning "Variable '$Name' already exists$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        }
    } catch {
        Write-Error "Variable '$Name', message: $_"
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
    
    $TaskName = $TaskName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })
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
                variables           = (ConvertFrom-Json-WithEmptyArray($Variables));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/automationtasks/powershell")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $taskGuid = $response.automationTaskGuid
            Write-Information "Powershell task '$TaskName' created$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        } else {
            #Get TaskGUID
            $taskGuid = $response.automationTaskGuid
            Write-Warning "Powershell task '$TaskName' already exists$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        }
    } catch {
        Write-Error "Powershell task '$TaskName', message: $_"
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
    $DatasourceName = $DatasourceName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })
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
                model              = (ConvertFrom-Json-WithEmptyArray($DatasourceModel));
                automationTaskGUID = $AutomationTaskGuid;
                value              = (ConvertFrom-Json-WithEmptyArray($DatasourceStaticValue));
                script             = $DatasourcePsScript;
                input              = (ConvertFrom-Json-WithEmptyArray($DatasourceInput));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
      
            $uri = ($script:PortalBaseUrl +"api/v1/datasource")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
              
            $datasourceGuid = $response.dataSourceGUID
            Write-Information "$datasourceTypeName '$DatasourceName' created$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        } else {
            #Get DatasourceGUID
            $datasourceGuid = $response.dataSourceGUID
            Write-Warning "$datasourceTypeName '$DatasourceName' already exists$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        }
    } catch {
      Write-Error "$datasourceTypeName '$DatasourceName', message: $_"
    }
    $returnObject.Value = $datasourceGuid
}
function Invoke-HelloIDDynamicForm {
    param(
        [parameter(Mandatory)][String]$FormName,
        [parameter(Mandatory)][String]$FormSchema,
        [parameter(Mandatory)][Ref]$returnObject
    )
    
    $FormName = $FormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })
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
                FormSchema = (ConvertFrom-Json-WithEmptyArray($FormSchema));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/forms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
    
            $formGuid = $response.dynamicFormGUID
            Write-Information "Dynamic form '$formName' created$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        } else {
            $formGuid = $response.dynamicFormGUID
            Write-Warning "Dynamic form '$FormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        }
    } catch {
        Write-Error "Dynamic form '$FormName', message: $_"
    }
    $returnObject.Value = $formGuid
}
function Invoke-HelloIDDelegatedForm {
    param(
        [parameter(Mandatory)][String]$DelegatedFormName,
        [parameter(Mandatory)][String]$DynamicFormGuid,
        [parameter()][Array][AllowEmptyString()]$AccessGroups,
        [parameter()][String][AllowEmptyString()]$Categories,
        [parameter(Mandatory)][String]$UseFaIcon,
        [parameter()][String][AllowEmptyString()]$FaIcon,
        [parameter()][String][AllowEmptyString()]$task,
        [parameter(Mandatory)][Ref]$returnObject
    )
    $delegatedFormCreated = $false
    $DelegatedFormName = $DelegatedFormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })
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
                useFaIcon       = $UseFaIcon;
                faIcon          = $FaIcon;
                task            = ConvertFrom-Json -inputObject $task;
            }
            if(-not[String]::IsNullOrEmpty($AccessGroups)) { 
                $body += @{
                    accessGroups    = (ConvertFrom-Json-WithEmptyArray($AccessGroups));
                }
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
    
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Information "Delegated form '$DelegatedFormName' created$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
            $delegatedFormCreated = $true
            $bodyCategories = $Categories
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormGuid/categories")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $bodyCategories
            Write-Information "Delegated form '$DelegatedFormName' updated with categories"
        } else {
            #Get delegatedFormGUID
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Warning "Delegated form '$DelegatedFormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
        }
    } catch {
        Write-Error "Delegated form '$DelegatedFormName', message: $_"
    }
    $returnObject.value.guid = $delegatedFormGuid
    $returnObject.value.created = $delegatedFormCreated
}

<# Begin: HelloID Global Variables #>
foreach ($item in $globalHelloIDVariables) {
	Invoke-HelloIDGlobalVariable -Name $item.name -Value $item.value -Secret $item.secret 
}
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
$dataSourceGuid_1_Name = @'
AD-group-create-check-names
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_1_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -returnObject ([Ref]$dataSourceGuid_1) 
<# End: DataSource "AD-group-create-check-names" #>

<# Begin: DataSource "AD-user-generate-table-groupmanagers-create-group" #>
$tmpPsScript = @'
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
'@ 
$tmpModel = @'
[{"key":"SamAccountName","type":0},{"key":"Title","type":0},{"key":"Description","type":0},{"key":"Company","type":0},{"key":"Department","type":0},{"key":"displayName","type":0},{"key":"UserPrincipalName","type":0},{"key":"selected","type":0}]
'@ 
$tmpInput = @'
[{"description":null,"translateDescription":false,"inputFieldType":1,"key":"selectedGroup","type":0,"options":0}]
'@ 
$dataSourceGuid_0 = [PSCustomObject]@{} 
$dataSourceGuid_0_Name = @'
AD-user-generate-table-groupmanagers-create-group
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_0_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -returnObject ([Ref]$dataSourceGuid_0) 
<# End: DataSource "AD-user-generate-table-groupmanagers-create-group" #>
<# End: HelloID Data sources #>

<# Begin: Dynamic Form "AD Group - Create" #>
$tmpSchema = @"
[{"label":"Details","fields":[{"key":"name","templateOptions":{"label":"Name","required":true,"minLength":5,"pattern":"^[A-Za-z0-9._-]{6,50}$"},"validation":{"messages":{"pattern":"Allowed characters: a-z 0-9 . _ - \nMinimal 6, maximum 50 characters"}},"type":"input","summaryVisibility":"Hide element","requiresTemplateOptions":true},{"key":"description","templateOptions":{"label":"Description"},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true},{"key":"formRow","templateOptions":{},"fieldGroup":[{"key":"groupScope","templateOptions":{"label":"Group scope","useObjects":true,"options":[{"value":"DomainLocal","label":"Domain local"},{"value":"Global","label":"Global"},{"value":"Universal","label":"Universal"}],"required":true},"type":"radio","summaryVisibility":"Show","textOrLabel":"label","requiresTemplateOptions":true},{"key":"groupType","templateOptions":{"label":"Group type","useObjects":true,"options":[{"value":"Security","label":"Security"},{"value":"Distribution","label":"Distribution"}],"required":true},"type":"radio","summaryVisibility":"Show","textOrLabel":"label","requiresTemplateOptions":true}],"type":"formrow","requiresTemplateOptions":true},{"key":"email","templateOptions":{"label":"Email","pattern":"(?:[a-z0-9!#$%\u0026\u0027*+/=?^_{|}~-]+(?:\\.[a-z0-9!#$%\u0026\u0027*+/=?^_{|}~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"},"validation":{"messages":{"pattern":"Invalid email address"}},"hideExpression":"model[\"groupType\"]!==\u0027Distribution\u0027","type":"email","summaryVisibility":"Hide element","requiresTemplateOptions":true},{"key":"manager","templateOptions":{"label":"AD group manager","required":false,"grid":{"columns":[{"headerName":"DisplayName","field":"displayName"},{"headerName":"UserPrincipalName","field":"UserPrincipalName"},{"headerName":"Department","field":"Department"},{"headerName":"Title","field":"Title"},{"headerName":"Description","field":"Description"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_0","input":{"propertyInputs":[]}},"useFilter":true},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true}]},{"label":"Naming","fields":[{"key":"naming","templateOptions":{"label":"Naming convention","required":true,"grid":{"columns":[{"headerName":"Name","field":"name"},{"headerName":"Email","field":"email"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_1","input":{"propertyInputs":[{"propertyName":"inputName","otherFieldValue":{"otherFieldKey":"name"}},{"propertyName":"inputEmail","otherFieldValue":{"otherFieldKey":"email"}}]}},"useFilter":false},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true}]}]
"@ 

$dynamicFormGuid = [PSCustomObject]@{} 
$dynamicFormName = @'
AD Group - Create
'@ 
Invoke-HelloIDDynamicForm -FormName $dynamicFormName -FormSchema $tmpSchema  -returnObject ([Ref]$dynamicFormGuid) 
<# END: Dynamic Form #>

<# Begin: Delegated Form Access Groups and Categories #>
$delegatedFormAccessGroupGuids = @()
if(-not[String]::IsNullOrEmpty($delegatedFormAccessGroupNames)){
    foreach($group in $delegatedFormAccessGroupNames) {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/groups/$group")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
            $delegatedFormAccessGroupGuid = $response.groupGuid
            $delegatedFormAccessGroupGuids += $delegatedFormAccessGroupGuid
            
            Write-Information "HelloID (access)group '$group' successfully found$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormAccessGroupGuid })"
        } catch {
            Write-Error "HelloID (access)group '$group', message: $_"
        }
    }
    if($null -ne $delegatedFormAccessGroupGuids){
        $delegatedFormAccessGroupGuids = ($delegatedFormAccessGroupGuids | Select-Object -Unique | ConvertTo-Json -Depth 100 -Compress)
    }
}
$delegatedFormCategoryGuids = @()
foreach($category in $delegatedFormCategories) {
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories/$category")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        $response = $response | Where-Object {$_.name.en -eq $category}
        
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid
        
        Write-Information "HelloID Delegated Form category '$category' successfully found$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    } catch {
        Write-Warning "HelloID Delegated Form category '$category' not found"
        $body = @{
            name = @{"en" = $category};
        }
        $body = ConvertTo-Json -InputObject $body -Depth 100
        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid
        Write-Information "HelloID Delegated Form category '$category' successfully created$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    }
}
$delegatedFormCategoryGuids = (ConvertTo-Json -InputObject $delegatedFormCategoryGuids -Depth 100 -Compress)
<# End: Delegated Form Access Groups and Categories #>

<# Begin: Delegated Form #>
$delegatedFormRef = [PSCustomObject]@{guid = $null; created = $null} 
$delegatedFormName = @'
AD Group - Create
'@
$tmpTask = @'
{"name":"AD Group - Create","script":"$description = $form.description\r\n$email = $form.naming.email\r\n$groupScope = $form.groupScope\r\n$groupType = $form.groupType\r\n$manager = $form.manager.UserPrincipalName\r\n$name = $form.naming.name\r\n\r\ntry {\r\n    $ADGroupParams = @{\r\n        Name           = $name\r\n        DisplayName    = $name\r\n        SamAccountName = $name\r\n        GroupCategory  = $groupType \r\n        GroupScope     = $groupScope\r\n        Description    = $description\r\n        Path           = $ADgroupsCreateOU\r\n    }\r\n    \r\n    if($manager -ne \"\") {\r\n        $managerObject = Get-ADuser -Filter { UserPrincipalName -eq $manager }\r\n        $ADGroupParams.Add( \u0027managedBy\u0027, $managerObject )\r\n    }\r\n    \r\n    if($email -ne \"\") {\r\n        $ADGroupParams.Add( \u0027OtherAttributes\u0027, @{mail=\"$email\"} )\r\n    }\r\n    \r\n    New-ADGroup @ADGroupParams\r\n    \r\n    Write-Information \"AD group [$name] created successfully\"\r\n    $Log = @{\r\n            Action            = \"CreateResource\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = \"AD group [$name] created successfully\" # required (free format text) \r\n            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $name # optional (free format text) \r\n            TargetIdentifier  = $name # optional (free format text) \r\n        }\r\n        #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log\r\n\r\n} catch {\r\n    Write-Error \"Error creating AD group [$name]. Error: $($_.Exception.Message)\" \r\n    $Log = @{\r\n            Action            = \"CreateResource\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = \"Error creating AD group [$name]. Error: $($_.Exception.Message)\" # required (free format text) \r\n            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $name # optional (free format text) \r\n            TargetIdentifier  = $name # optional (free format text) \r\n        }\r\n        #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log\r\n}","runInCloud":false}
'@ 

Invoke-HelloIDDelegatedForm -DelegatedFormName $delegatedFormName -DynamicFormGuid $dynamicFormGuid -AccessGroups $delegatedFormAccessGroupGuids -Categories $delegatedFormCategoryGuids -UseFaIcon "True" -FaIcon "fa fa-plus" -task $tmpTask -returnObject ([Ref]$delegatedFormRef) 
<# End: Delegated Form #>

