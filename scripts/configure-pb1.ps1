# Fetch configuration's file
$configurationPath = "config.json"

$config = Get-Content -Path $configurationPath | ConvertFrom-Json
if (!$config) {
  Write-Error "Provided config file is empty - filepath: $configurationPath."
  exit(1)
}

# Import module
Import-Module $PSScriptRoot\functions.ps1 -Force

# Fetch authenitcation from key vault
$clientid = $env:ARM_CLIENT_ID
$clientSecret = ConvertTo-SecureString $env:ARM_CLIENT_SECRET -AsPlainText -Force
$tenantId = $env:ARM_TENANT_ID

# $clientid = "c0a6b74a-26d1-4841-b66a-f449fe5f6296"

## login to power BI
Get-PSRepository
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser

$credential = New-Object System.Management.Automation.PSCredential($clientid, $clientSecret)
try {
  Connect-PowerBIServiceAccount -Credential $credential -ServicePrincipal -Tenant $tenantId
}
catch {
  Write-Error "Failed to log into Power BI Service as clientId: $($clientid)."
  exit(1)
}
Write-Host "Now logged into Power BI Service as clientId: $($clientid)."

##### Below code use to fetch pattoken from Keyvault, forthis, add pattoken in keyvault, update config file, and grant Service Connection with permissions to get the secret
# $pattoken    = (az keyvault secret show --vault-name $config.keyVault.name --name $config.keyVault.pattoken --output json | ConvertFrom-Json).value

$pattoken2    = "dapi5cfddc979b24bc3534aec6ff6111db4f-2"

# Fetching workspace and report information
Write-Host "Retrieving information from Workspace: $($config.workspacename)."

$workspace = Get-PowerBIWorkspace -Name $config.workspacename

# knowledge: report with 1 datasource: 1) Databricks
$reports = $config.reports.name

$report1    = Get-PowerBIReport    -WorkspaceId $workspace.Id | Where-Object { $_.Name -eq $report }
if(!$report1) {
  Write-Error "Report $report was not found on workspace $($config.workspacename)"
  exit(1)
}
$dataset   = Get-PowerBIDataset   -WorkspaceId $workspace.Id | Where-Object { $_.Name -eq $report }
if(!$dataset) {
  Write-Error "Dataset $report was not found on workspace $($config.workspacename)"
  exit(1)
}

#region takeover
Write-Host "Dataset takeover for $($dataset.Name)(id: $($dataset.Id)) started."
if ((Invoke-ReportBIDatasetTakeover -WorkspaceId $workspace.Id -DatasetId $dataset.Id ) -ne $true) {
  exit(1)
}
Write-Host "Dataset takeover $($dataset.Name)(id: $($dataset.Id)) done."
#endregion takeover 

$datasource = Get-PowerBIDatasource -DatasetId $dataset.Id -WorkspaceId $workspace.Id 

#### Update Databrick Credentials
Write-Host "Update datasource credentials [databricks] for $($dataset.Name)(id: $($dataset.Id))"

$gatewayId = $datasource.GatewayId
$datasourceId = $datasource.DatasourceId
$url = "https://api.powerbi.com/v1.0/myorg/gateways/$($gatewayId)/datasources/$($datasourceId)"

$patchCredentials = @{
  credentialData = @(
      @{
        name = "key"    
        value = $pattoken  ### ADD PAT TOKEN - created by pipeline and stored in KeyVault
      }
  )
} | ConvertTo-Json -Compress

$body = @{             
credentialDetails = @{
    credentialType = "Key"
    credentials = "$($patchCredentials)"
    encryptedConnection = "Encrypted"
    encryptionAlgorithm = "None"
    privacyLevel = "Organizational"
    }
} | ConvertTo-Json -Compress

try {
Invoke-PowerBIRestMethod -Url $url -Method Patch -Body $body -ContentType $content
}
catch {
  Write-Host "The PowerBI request for $url for UpdateCredentials Failed with exception: $_.Exception"
  Resolve-PowerBIError -last
  exit(1)
}


