#HelloID variables
$PortalBaseUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupName = "Users"
 
# Create authorization headers with HelloID API key
$pair = "$apiKey" + ":" + "$apiSecret"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$key = "Basic $base64"
$headers = @{"authorization" = $Key}
# Define specific endpoint URI
if($PortalBaseUrl.EndsWith("/") -eq $false){
    $PortalBaseUrl = $PortalBaseUrl + "/"
}
 
 
 
$variableName = "ADusersSearchOU"
$variableGuid = ""
   
try {
    $uri = ($PortalBaseUrl +"api/v1/automation/variables/named/$variableName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
   
    if([string]::IsNullOrEmpty($response.automationVariableGuid)) {
        #Create Variable
        $body = @{
            name = "$variableName";
            value = '[{ "OU": "OU=Employees,OU=Users,OU=Enyoi,DC=enyoi-media,DC=local"},{ "OU": "OU=Disabled,OU=Users,OU=Enyoi,DC=enyoi-media,DC=local"},{"OU": "OU=External,OU=Users,OU=Enyoi,DC=enyoi-media,DC=local"}]';
            secret = "false";
            ItemType = 0;
        }
   
        $body = $body | ConvertTo-Json
   
        $uri = ($PortalBaseUrl +"api/v1/automation/variable")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $variableGuid = $response.automationVariableGuid
    } else {
        $variableGuid = $response.automationVariableGuid
    }
   
    $variableGuid
} catch {
    $_
}
 
  
$variableName = "ADgroupsCreateOU"
$variableGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/automation/variables/named/$variableName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
  
    if([string]::IsNullOrEmpty($response.automationVariableGuid)) {
        #Create Variable
        $body = @{
            name = "$variableName";
            value = 'OU=HelloIDCreated,OU=Groups,OU=Enyoi,DC=enyoi-media,DC=local';
            secret = "false";
            ItemType = 0;
        }
  
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automation/variable")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $variableGuid = $response.automationVariableGuid
    } else {
        $variableGuid = $response.automationVariableGuid
    }
  
    $variableGuid
} catch {
    $_
}
  
  
  
$taskName = "AD-user-generate-table"
$taskGetUsersGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
  
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
  
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
try {
    $ous = $searchOUs | ConvertFrom-Json
 
    $users = foreach($item in $ous) {
        Get-ADUser -Filter {Name -like "*"} -SearchBase $item.ou -properties *
    }
     
    $users = $users | Sort-Object -Property DisplayName
    $resultCount = @($users).Count
    Hid-Write-Status -Message "Result count: $resultCount" -Event Information
    HID-Write-Summary -Message "Result count: $resultCount" -Event Information
     
    if($resultCount -gt 0){
        foreach($user in $users){
            $returnObject = @{SamAccountName=$user.SamAccountName; displayName=$user.displayName; UserPrincipalName=$user.UserPrincipalName; Description=$user.Description; Department=$user.Department; Title=$user.Title;}
            Hid-Add-TaskResult -ResultValue $returnObject
        }
    } else {
        Hid-Add-TaskResult -ResultValue []
    }
} catch {
    HID-Write-Status -Message "Error searching AD users. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Error searching AD users" -Event Failed
     
    Hid-Add-TaskResult -ResultValue []
}
'@;
            automationContainer = "1";
            variables = @(@{name = "searchOUs"; value = "{{variable.ADusersSearchOU}}"; typeConstraint = "string"; secret = "False"})
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskGetUsersGuid = $response.automationTaskGuid
  
    } else {
        #Get TaskGUID
        $taskGetUsersGuid = $response.automationTaskGuid
    }
} catch {
    $_
}
  
$taskGetUsersGuid
  
  
  
$dataSourceName = "AD-user-generate-table"
$dataSourceGetUsersGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
  
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
            model = @(@{key = "Department"; type = 0}, @{key = "Description"; type = 0}, @{key = "displayName"; type = 0}, @{key = "SamAccountName"; type = 0}, @{key = "Title"; type = 0}, @{key = "UserPrincipalName"; type = 0});
            automationTaskGUID = "$taskGetUsersGuid";
            input = @()
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
          
        $dataSourceGetUsersGuid = $response.dataSourceGUID
    } else {
        #Get DatasourceGUID
        $dataSourceGetUsersGuid = $response.dataSourceGUID
    }
} catch {}
$dataSourceGetUsersGuid
  
  
  
$taskName = "AD-group-create-check-names"
$taskCreateGroupCheckNamesGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
  
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
  
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
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
'@;
            automationContainer = "1";
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskCreateGroupCheckNamesGuid = $response.automationTaskGuid
  
    } else {
        #Get TaskGUID
        $taskCreateGroupCheckNamesGuid = $response.automationTaskGuid
    }
} catch {
    $_
}
  
$taskCreateGroupCheckNamesGuid
  
  
  
$dataSourceName = "AD-group-create-check-names"
$dataSourceCreateGroupCheckNamesGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
  
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
            model = @(@{key = "email"; type = 0}, @{key = "name"; type = 0});
            automationTaskGUID = "$taskCreateGroupCheckNamesGuid";
            input = @(@{description = ""; translateDescription = "False"; inputFieldType = "1"; key = "inputName"; type = "0"; options = "1"},
                    @{description = ""; translateDescription = "False"; inputFieldType = "1"; key = "inputEmail"; type = "0"; options = "0"})
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
          
        $dataSourceCreateGroupCheckNamesGuid = $response.dataSourceGUID
    } else {
        #Get DatasourceGUID
        $dataSourceCreateGroupCheckNamesGuid = $response.dataSourceGUID
    }
} catch {
    $_
}
  
$dataSourceCreateGroupCheckNamesGuid
 
 
 
  
$formName = "AD Group - Create"
$formGuid = ""
  
try
{
    try {
        $uri = ($PortalBaseUrl +"api/v1/forms/$formName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    } catch {
        $response = $null
    }
  
    if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true))
    {
        #Create Dynamic form
        $form = @"
[
  {
    "label": "Details",
    "fields": [
      {
        "key": "name",
        "templateOptions": {
          "label": "Name",
          "required": true,
          "minLength": 5,
          "pattern": "^[A-Za-z0-9._-]{6,50}$"
        },
        "validation": {
          "messages": {
            "pattern": "Allowed characters: a-z 0-9 . _ - \\nMinimal 6, maximum 50 characters"
          }
        },
        "type": "input",
        "summaryVisibility": "Hide element",
        "requiresTemplateOptions": true
      },
      {
        "key": "description",
        "templateOptions": {
          "label": "Description"
        },
        "type": "input",
        "summaryVisibility": "Show",
        "requiresTemplateOptions": true
      },
      {
        "key": "groupScope",
        "templateOptions": {
          "label": "Group scope",
          "useObjects": true,
          "options": [
            {
              "value": "DomainLocal",
              "label": "Domain local"
            },
            {
              "value": "Global",
              "label": "Global"
            },
            {
              "value": "Universal",
              "label": "Universal"
            }
          ],
          "required": true
        },
        "type": "radio",
        "summaryVisibility": "Show",
        "textOrLabel": "label",
        "requiresTemplateOptions": true
      },
      {
        "key": "groupType",
        "templateOptions": {
          "label": "Group type",
          "useObjects": true,
          "options": [
            {
              "value": "Security",
              "label": "Security"
            },
            {
              "value": "Distribution",
              "label": "Distribution"
            }
          ],
          "required": true
        },
        "type": "radio",
        "summaryVisibility": "Show",
        "textOrLabel": "label",
        "requiresTemplateOptions": true
      },
      {
        "key": "email",
        "templateOptions": {
          "label": "Email",
          "pattern": "(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|\\"(?:[\\\\x01-\\\\x08\\\\x0b\\\\x0c\\\\x0e-\\\\x1f\\\\x21\\\\x23-\\\\x5b\\\\x5d-\\\\x7f]|\\\\\\\\[\\\\x01-\\\\x09\\\\x0b\\\\x0c\\\\x0e-\\\\x7f])*\\")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\\\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\\\x01-\\\\x08\\\\x0b\\\\x0c\\\\x0e-\\\\x1f\\\\x21-\\\\x5a\\\\x53-\\\\x7f]|\\\\\\\\[\\\\x01-\\\\x09\\\\x0b\\\\x0c\\\\x0e-\\\\x7f])+)\\\\])"
        },
        "validation": {
          "messages": {
            "pattern": "Invalid email address"
          }
        },
        "hideExpression": "model[\\"groupType\\"]!=='Distribution'",
        "type": "email",
        "summaryVisibility": "Hide element",
        "requiresTemplateOptions": true
      },
      {
        "key": "manager",
        "templateOptions": {
          "label": "AD group manager",
          "required": false,
          "grid": {
            "columns": [
              {
                "headerName": "DisplayName",
                "field": "displayName"
              },
              {
                "headerName": "UserPrincipalName",
                "field": "UserPrincipalName"
              },
              {
                "headerName": "Department",
                "field": "Department"
              },
              {
                "headerName": "Title",
                "field": "Title"
              },
              {
                "headerName": "Description",
                "field": "Description"
              }
            ],
            "height": 300,
            "rowSelection": "single"
          },
          "dataSourceConfig": {
            "dataSourceGuid": "$dataSourceGetUsersGuid",
            "input": {
              "propertyInputs": []
            }
          },
          "useFilter": true
        },
        "type": "grid",
        "summaryVisibility": "Show",
        "requiresTemplateOptions": true
      }
    ]
  },
  {
    "label": "Naming",
    "fields": [
      {
        "key": "naming",
        "templateOptions": {
          "label": "Naming convention",
          "required": true,
          "grid": {
            "columns": [
              {
                "headerName": "Name",
                "field": "name"
              },
              {
                "headerName": "Email",
                "field": "email"
              }
            ],
            "height": 300,
            "rowSelection": "single"
          },
          "dataSourceConfig": {
            "dataSourceGuid": "$dataSourceCreateGroupCheckNamesGuid",
            "input": {
              "propertyInputs": [
                {
                  "propertyName": "inputEmail",
                  "otherFieldValue": {
                    "otherFieldKey": "email"
                  }
                },
                {
                  "propertyName": "inputName",
                  "otherFieldValue": {
                    "otherFieldKey": "name"
                  }
                }
              ]
            }
          },
          "useFilter": false
        },
        "type": "grid",
        "summaryVisibility": "Show",
        "requiresTemplateOptions": true
      }
    ]
  }
]
"@
  
        $body = @{
            Name = "$formName";
            FormSchema = $form
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/forms")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
  
        $formGuid = $response.dynamicFormGUID
    } else {
        $formGuid = $response.dynamicFormGUID
    }
} catch {
    $_
}
  
$formGuid
  
  
  
  
$delegatedFormAccessGroupGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/groups/$delegatedFormAccessGroupName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    $delegatedFormAccessGroupGuid = $response.groupGuid
} catch {
    $_
}
  
$delegatedFormAccessGroupGuid
  
  
  
$delegatedFormName = "AD Groep - Create"
$delegatedFormGuid = ""
  
try {
    try {
        $uri = ($PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    } catch {
        $response = $null
    }
  
    if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
        #Create DelegatedForm
        $body = @{
            name = "$delegatedFormName";
            dynamicFormGUID = "$formGuid";
            isEnabled = "True";
            accessGroups = @("$delegatedFormAccessGroupGuid");
            useFaIcon = "True";
            faIcon = "fa fa-plus";
        }  
  
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/delegatedforms")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
  
        $delegatedFormGuid = $response.delegatedFormGUID
    } else {
        #Get delegatedFormGUID
        $delegatedFormGuid = $response.delegatedFormGUID
    }
} catch {
    $_
}
  
$delegatedFormGuid
  
  
  
  
$taskActionName = "AD-group-create"
$taskActionGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskActionName&container=8")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskActionName}
  
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
  
        $body = @{
            name = "$taskActionName";
            useTemplate = "false";
            powerShellScript = @'
try {
    $ADGroupParams = @{
        Name           = $name
        DisplayName    = $name
        SamAccountName = $name
        GroupCategory  = $groupType
        GroupScope     = $groupScope
        Description    = $description
        Path           = $createOU
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
            automationContainer = "8";
            objectGuid = "$delegatedFormGuid";
            variables = @(@{name = "createOU"; value = "{{variable.ADgroupsCreateOU}}"; typeConstraint = "string"; secret = "False"},
                        @{name = "description"; value = "{{form.description}}"; typeConstraint = "string"; secret = "False"},
                        @{name = "email"; value = "{{form.naming.email}}"; typeConstraint = "string"; secret = "False"},
                        @{name = "groupScope"; value = "{{form.groupScope}}"; typeConstraint = "string"; secret = "False"},
                        @{name = "groupType"; value = "{{form.groupType}}"; typeConstraint = "string"; secret = "False"},
                        @{name = "manager"; value = "{{form.manager.UserPrincipalName}}"; typeConstraint = "string"; secret = "False"},
                        @{name = "name"; value = "{{form.naming.name}}"; typeConstraint = "string"; secret = "False"});
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskActionGuid = $response.automationTaskGuid
  
    } else {
        #Get TaskGUID
        $taskActionGuid = $response.automationTaskGuid
    }
} catch {
    $_
}
  
$taskActionGuid