$then = Get-Date
Write-Host "Elapsed Time: $($(Get-Date) - $then)"
Write-Host "Getting VM statistics..."


$allRegions = Get-AzureRmLocation
$allSizes = @{}
foreach( $region in $allRegions )
{
  $allSizes[ $region.Location ] = Get-AzureRmVMSize -Location $region.Location
}



$allVMStatus = Get-AzureRmVM -Status
#$allVMStatus = Get-Content -Raw -Path "cache.vms.json" | ConvertFrom-Json
$sas = Get-AzureRmStorageAccount
#Get-Content -Raw -Path "cache.sa.json" | ConvertFrom-Json 
Write-Host "Elapsed Time: $($(Get-Date) - $then)"



$finalResults = @()

#$onlyDo = 40

foreach( $vm in $allVMStatus )
{
   

#  $onlyDo--
#  if( $onlyDo -lt 0 )
#  {
#    break
#  }
  Write-Host "[" -NoNewline -ForegroundColor White
  Write-Host "$($(Get-Date) - $then)" -NoNewline -ForegroundColor Yellow
  Write-Host "] " -NoNewline -ForegroundColor White
  $deallocated = $false
  if( $vm.PowerState -imatch "VM deallocated" )
  {
      Write-Host " [OFF] " -NoNewline -ForegroundColor Gray
      $deallocated = $true
  }
  else
  {
      Write-Host " [ ON] " -NoNewline -ForegroundColor Green 
  }

  Write-Host "-Name $($vm.Name) " -NoNewline
  Write-Host "-ResourceGroup $($vm.ResourceGroupName) " -NoNewline
  Write-Host "Size=" -NoNewline
  Write-Host "$($vm.HardwareProfile.VmSize)" -NoNewline -ForegroundColor Yellow

  $storageKind = "None"
  $ageDays = -1
  $idleDays = -1

  if( $vm.StorageProfile.OsDisk.Vhd.Uri )
  {
    $vhd = $vm.StorageProfile.OsDisk.Vhd.Uri
    $storageAccount = $vhd.Split("/")[2].Split(".")[0]
    $container = $vhd.Split("/")[3]
    $blob = $vhd.Split("/")[4]

    $storageKind = "blob"

    $foo = $sas | where {  $($_.StorageAccountName -eq $storageAccount) -and $($_.Location -eq $vm.Location) }
    # Suppress the name
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $foo.ResourceGroupName -Name $storageAccount > $null

#        Set-AzureRmCurrentStorageAccount -ResourceGroupName Default-Storage-$($vm.location) -Name $storageAccount > $null
#        Set-AzureRmCurrentStorageAccount -ResourceGroupName $vm.ResourceGroupName -Name $storageAccount > $null

    $blobDetails = Get-AzureStorageBlob -Container $container -Blob $blob
    $copyCompletion = $blobDetails.ICloudBlob.CopyState.CompletionTime
    $lastWriteTime = $blobDetails.LastModified
    $age = $($(get-Date)-$copyCompletion.DateTime)
    $idle = $($(Get-Date)-$lastWriteTime.DateTime)
    $ageDays = $age.Days
    $idleDays = $idle.Days
 
    Write-Host " Age = $ageDays" -NoNewline
    Write-Host " Idle = $idleDays"
  }
  else
  {
    $storageKind = "disk"
    $osdisk = Get-AzureRmDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name
    if( $osdisk.TimeCreated )
    {
      $age = $($(Get-Date) - $osDisk.TimeCreated)
      $ageDays = $($age.Days)
      Write-Host " Age = $($age.Days)"
    }
  }
  $coreCount = $allSizes[ $vm.Location ] | where { $_.Name -eq $($vm.HardwareProfile.VmSize) }
  $newEntry = @{
    Name=$vm.Name
    resourceGroup=$vm.ResourceGroupName
    location=$vm.Location
    coreCount=$coreCount.NumberOfCores
    vmSize=$($vm.HardwareProfile.VmSize)
    Age=$ageDays
    Idle=$idleDays
    Weight=$($coreCount.NumberOfCores * $ageDays)
    StorageKind=$storageKind
    Deallocated=$deallocated
  }

  $finalResults += $newEntry
}
Write-Host "FinalResults.Count = $($finalResults.Count)"
$finalResults | ConvertTo-Json -Depth 10 | Set-Content "cache.results.json"

Copy-Item "cache.results.json" "Z:\Jenkins_Shared_Do_Not_Delete\userContent\shared\" -Force -Verbose
