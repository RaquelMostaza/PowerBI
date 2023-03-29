
function Invoke-ReportBIDatasetTakeover {
  param (
      [Parameter(Mandatory = $true)]
      [string] $WorkspaceId, 

      [Parameter(Mandatory = $true)]
      [string] $DatasetId
  )
  
  $apiUrl = "https://api.powerbi.com/v1.0/myorg/groups/$($WorkspaceId)/datasets/$($DatasetId)/Default.Takeover"
  try {
      Write-Host "Invoke-PowerBIRestMethod -Method Post -Url $($apiUrl) -Body @{}"
      Invoke-PowerBIRestMethod -Method Post -Url $apiUrl -Body @{} # does not return a status code ... 
  }
  catch {
      Write-Error "Takeover of dataset $($DatasetId) failed."
      Resolve-PowerBIError -last
      return $false
  }
  Start-Sleep -Seconds 15 #take over operation is not always instant even if http statuscode 200 is returned
  Write-Host "Takeover of dataset $($DatasetId) succeeded."
  return $true
}
