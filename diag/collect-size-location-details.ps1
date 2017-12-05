#!/usr/bin/pwsh
$locationList = az account list-locations | ConvertFrom-Json
foreach( $location in $locationList )
{
  $name = $location.name
  Write-Host "Outputting the VM sizes for $($location.displayName)"
  az vm list-sizes --location $name > /diag/vmsizes.$name.json.cache
}
