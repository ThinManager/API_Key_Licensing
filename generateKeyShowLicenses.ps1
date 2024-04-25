####    Script to generate a long-term use key for the ThinManager API     #####
#### Also demonstrates how to get licensing info from a ThinManager server #####

#Define parameters for this script

#initialize the variable to store the API login info
$loginInfoREST = ''

#Initialize headers for REST API calls
$headersPost = $null
$headersGet = $null
$apiKey = $null

## Define Functions for this code ##

#Function to enable the API
function Invoke-EnableAPI {
  #Stop the ThinServer service to enable the API and then wait a minute
  Write-Host "Enabling the API"
  Stop-Service -Name ThinServer -Force
    
  #Create a registry value that enables the API
  $regPath = "HKLM:\Software\Automation Control Products\ThinManager"
  $regName = "EnableAPI"
  $regValue = 1
  New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType DWord -Force
  #Write-Host "Created Registry Entry to enable API, starting the ThinServer service"
    
  #Start the ThinServer service to enable the API and wait
  Start-Service ThinServer
  #   Write-Host "Starting ThinServer service and waiting 60 seconds"
  #   Start-Sleep -Seconds 60
}

#function to log into the API
function Invoke-LoginAPI {
  #Prompt user to enter in a valid username and password
  Write-Host "### Log into the ThinManager API ###"
  $username = Read-Host -Prompt "Domain\Username"
  $password = Read-Host -AsSecureString -Prompt "Password"

  #Get a valid key to use with the ThinManager server
  Write-Host "Getting a valid key to use with the ThinManager server"
  $loginHeaders = @{
    'accept'       = 'application/json'
    'Content-Type' = 'application/json'
  }
  $loginData = @{
    'Username' = $username
    'Password' = ConvertFrom-SecureString -SecureString $password -AsPlainText
  }

  $result = $null
  $httpCode = $null

  #attempt login for 2 minutes
  $count = 24
  while ($count -ge 0) {
    $result = Invoke-RestMethod -Uri 'https://localhost:8443/api/login' -Method POST -Body (ConvertTo-Json $loginData) -Headers $loginHeaders -SkipCertificateCheck -SkipHttpErrorCheck -StatusCodeVariable "httpCode"
    if ($null -ne $result.Key) { break }
    $count--
    Start-Sleep 5
  }

  if ($null -eq $result.Key) {
    Write-Host "Unable to get a valid key to use with the ThinManager server"
    $result = $httpCode
  }
  return $result
}

#Function that generates a persistent ThinManager API key
function Invoke-GenerateKey {
  $body = '{
    "Name": "New Key 3",
    "Quota": 1000,
    "QuotaPeriod": 3600,
    "DisableAt": "05/15/23 22:22",
    "Permissions": [
      "Connect",
      "Shadow",
      "Interactive Shadow",
      "Reset Sessions",
      "Kill Processes",
      "Reboot Terminal Servers",
      "Connect To Terminal Servers",
      "Logoff TermSecure Users",
      "ThinServer Administration",
      "Create Terminals",
      "Create Users",
      "Create Application Groups",
      "Create Terminal Servers",
      "Edit Terminals",
      "Edit Users",
      "Edit Application Groups",
      "Edit Terminal Servers",
      "Install Files",
      "Calibrate Touchscreens",
      "Reboot Terminals",
      "Restart Terminals",
      "Schedule Events",
      "Change Licenses",
      "Allow Printing",
      "Create Cameras",
      "Edit Cameras",
      "View Cameras",
      "Create VMWare",
      "Edit VMWare",
      "VMWare Operations",
      "Create DHCP",
      "Edit DHCP",
      "Create Package",
      "Edit Package",
      "Create Location",
      "Edit Location",
      "Logoff Location",
      "Create Resolver",
      "Edit Resolver",
      "Replace Terminal",
      "ThinManager Server List",
      "Create VNC",
      "Edit VNC",
      "Create Container",
      "Edit Container",
      "Create Events",
      "Edit Events"
    ]
  }'

  $uri = "https://localhost:8443/api/system/api/keys"
  Invoke-RestMethod -Uri $uri -Method Post -Body $body -Headers $headersPost -SkipCertificateCheck
}

#Function that gets the TMA licensing info of a ThinManager system and returns it as a PowerShell Object
function Invoke-GetLicenseInfoTMA {

  $uri = "https://localhost:8443/api/system/licensing/tma/license"
  return Invoke-RestMethod -Uri $uri -Method GET -Headers $headersGet -SkipCertificateCheck
}

#Function that gets the TMA licensing info of a ThinManager system and returns it as a PowerShell Object
function Invoke-GetLicenseInfoFTA {

  $uri = "https://localhost:8443/api/system/licensing/fta/licenses"
  return Invoke-RestMethod -Uri $uri -Method GET -Headers $headersGet -SkipCertificateCheck
}

### START CODE ###

# #Uncomment to call the function to enable the API through the Windows Registry and ThinServer service restarts
# Invoke-EnableAPI

Write-Host "Starting the process of generating a ThinManager API Key" -ForegroundColor Green

#generate a key and store in the $loginInfoREST variable
$loginInfoREST = Invoke-LoginAPI

if (401 -eq $loginInfoREST) {
  Write-Host "Could not log into the API, check username, password, and settings of ThinManager server"
}

else {

  $apiKey = $loginInfoREST.Key
  Write-Host "The generated ThinManager API key from the login is: $apiKey"

  #set the header data to be used in the following functions
  $headersPost = @{
    'accept'       = 'application/json'
    'Content-Type' = 'application/json'
    'x-api-key'    = $loginInfoREST.Key
  }
  
  $headersGet = @{
    'accept'    = 'application/json'
    'x-api-key' = $loginInfoREST.Key
  }

  $apiGenerateResult = Invoke-GenerateKey
  $newApiKey = $apiGenerateResult.Key
  Write-Host "The generated ThinManager API key from the POST is: $newApiKey"

  $licenseInfoTMA = Invoke-GetLicenseInfoTMA
  $licenseInfoJsonTMA = ConvertTo-Json -InputObject $licenseInfoTMA -Depth 5
  Write-Host "The TMA license info for the server is: $licenseInfoJsonTMA"

  $licenseInfoFTA = Invoke-GetLicenseInfoFTA
  $licenseInfoJsonFTA = ConvertTo-Json -InputObject $licenseInfoFTA -Depth 5
  Write-Host "The FTA license info for the server is: $licenseInfoJsonFTA"
    
}
