#!/usr/bin/pwsh
$vms = az vm list | ConvertFrom-Json
$results = @()

$now = $(Get-Date).ToUniversalTime()

$failedToRead = $false

Write-Host "Processing $($vms.Count) entries."
$vmIndex = 0
$failMax = 1
$failCount = 0

foreach( $vm in $vms )
{
    $vmIndex++
    $vmName = $vm.name
    $resourceGroup = $vm.resourceGroup
    $vmSize = $vm.hardwareProfile.vmSize
    $location = $vm.location

    $officialSizes = Get-Content -Raw -Path "/diag/vmsizes.$location.json.cache" | ConvertFrom-Json 
    if( $officialSizes ) 
    {
      $officialSize = $officialSizes | where { $_.name -eq $vmSize }
    if( $officialSize )
    {
      $vmSize = $officialSize.numberOfCores
      Write-Host "New size (in cores) $vmSize"
    }
    }
    Write-Host "vmSize = $vmSize"


    $vmDays = 0
    $osdisk = $vm.storageProfile.osdisk
    $location = $vm.location
    $storageKind = "None"
    
    Write-Host "[$vmIndex] Investigating: -g $resourceGroup -n $vmName ..."
    ## Two options here.  Disks stored with a storage account ...
    $vhd = $osdisk.vhd.uri
    $failCount = 0
    do
    {
        if( $failedToRead )
        {
            $failCount++
            Write-Host "Sleeping for 20 seconds."
            Start-Sleep -s 20
            Write-Host "Waking up and trying again."
            
        }
        $failedToRead = $true
        if( $vhd )
        {
            # TODO: This works because we have no variance.
            # The url for the vhd is of the form:  http://[StorageAccount].some.azure.url/[ContainerName]/[Blob]
            ## Retrieve the blob from the Storage account.
            $storageAccount = $vhd.Split("/")[2].Split(".")[0]
            $container = $vhd.Split("/")[3]
            $blob = $vhd.Split("/")[4]
            $blobDetail = az storage blob show --account-name $storageAccount --container-name $container --name $blob | ConvertFrom-Json
            if( $blobDetail )
            {
                $failedToRead = $false
                # Retrieve when the drive was initially copied to the container.
                $then = $blobDetail.properties.copy.completionTime
                $vmDays = $($now - $then).Days
                # Get the last modified time.
                $lastAccessTime = $blobDetail.properties.lastModified
                $vmIdle = $($now - $lastAccessTime).Days
                # Mark this as a blob so we can differentiate later how this was stored.
                $storageKind = "blob"
            }
        }
        else
        {
            ## Simplest case. No storage account.
            $diskName = $osdisk.name
            if( $diskName )
            {
                $diskDetail = az disk show -g $resourceGroup -n $diskName | ConvertFrom-Json
                if( $diskDetail )
                {
                    $failedToRead = $false
                    # Retrieve the creation time for the drive.
                    $then = $diskDetail.timeCreated
                    $vmDays = $($now - $then).Days
                    # TODO: No last-accessed time for disk drives. -- Checked Nov 2017 -- seansp
                    # Mark this as a disk so we can differentiate later how this was stored.
                    $storageKind = "disk"
                }
            }
        }
       if( $failCount -ge $failMax )
       {
         Write-Host "Exceeded Failure Retry Count."
         $failedToRead = $false
       }
    }  while( $failedToRead  )
    $result = @{
        name=$vmName
        vmSize=$vmSize
        resourceGroup=$resourceGroup
        location=$location
        ageInDays=$vmDays
        idleDays=$vmIdle
        storageKind=$storageKind
    }
    $results += $result
    Write-Host "$vmName`t$vmSize`t$resourceGroup`t$vmDays"
}
Write-Host "Finished.  Formatting results..."
foreach( $result in $results | Sort-Object -Property ageInDays -Descending )
{
    Write-Host "$($result.name)`t$($result.resourceGroup)`t$($result.location)`t$($result.vmSize)`t$($result.ageInDays)`t$($result.idleDays)`t$($result.$storageKind)"
}
