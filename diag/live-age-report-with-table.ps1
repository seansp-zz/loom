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
    $location = $vm.location.ToLower()  # southindia VMs sometimes claim SouthIndia

    $officialSizes = Get-Content -Raw -Path "/diag/vmsizes.$location.json.cache" | ConvertFrom-Json 
    if( $officialSizes ) 
    {
      $officialSize = $officialSizes | where { $_.name -eq $vmSize }
    if( $officialSize )
    {
      $vmCoreCount = $officialSize.numberOfCores
      Write-Host "New size (in cores) $vmCoreCount"
    }
    }
    Write-Host "$vmSize = $vmCoreCount Cores"


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
        vmCoreCount=$vmCoreCount
        resourceGroup=$resourceGroup
        location=$location
        ageInDays=$vmDays
        idleDays=$vmIdle
        storageKind=$storageKind
        weightedScore=$($vmDays * $vmCoreCount)
    }
    $results += $result
    Write-Host "$vmName`t$vmCoreCount`t$resourceGroup`t$vmDays"
}
Write-Host "Finished.  Formatting results..."
Write-Host "Creating two reports.  All-Ages and Top-100."

$sbShort = New-Object System.Text.StringBuilder
$sbLong = New-Object System.Text.StringBuilder


$htmlHeader = "
<html>
<head>
  <script type=`"text/javascript`" src=`"https://www.gstatic.com/charts/loader.js`"></script>
  <script type=`"text/javascript`">
    google.charts.load('current', {'packages':['table']});
    google.charts.setOnLoadCallback(drawTable);

    function drawTable() {
      var data = new google.visualization.DataTable();
      data.addColumn('string', 'Name');
      data.addColumn('string', 'Resource Group');
      data.addColumn('string', 'Location');
      data.addColumn('number', 'Core Count');
      data.addColumn('string', 'vmSize');
      data.addColumn('number', 'Age in Days');
      data.addColumn('number', 'Idle Days (for storage)');
      data.addColumn('number', 'Weight (age*cores)');
      data.addColumn('string', 'Storage Kind');
      data.addRows([
"
$date = Get-Date
$htmlFooter = "
]);

        var table = new google.visualization.Table(document.getElementById('table_div'));

        table.draw(data, {showRowNumber: true, width: '100%', height: '100%'});
      }
    </script>
  </head>
  <body>
    Table generated: $date 
    <div id=`"table_div`"></div>
  </body>
</html>
"

$rowCount = 0
foreach( $result in $results | Sort-Object -Property weightedScore -Descending )
{
    $rowCount++
    Write-Host "$($result.name)`t$($result.resourceGroup)`t$($result.location)`t$($result.vmSize)`t$($result.ageInDays)`t$($result.idleDays)`t$($result.$storageKind)"
    if( $rowCount -le 100 )
    {
        $sbShort.Append( "['$($result.name)', '$($result.resourceGroup)','$($result.location)',$($result.vmCoreCount),'$($result.vmSize)',$($result.ageInDays),$($result.idleDays),$($result.weightedScore),'$($result.$storageKind)'],")
    }
    $sbLong.Append( "['$($result.name)', '$($result.resourceGroup)','$($result.location)',$($result.vmCoreCount),'$($result.vmSize)',$($result.ageInDays),$($result.idleDays),$($result.weightedScore),'$($result.$storageKind)'],")
}


Remove-Item -Path top100.html
Add-Content -Path top100.html $htmlHeader
Add-Content -Path top100.html $sbShort.ToString()
Add-Content -Path top100.html $htmlFooter
Remove-Item -Path completeList.html
Add-Content -Path completeList.html $htmlHeader
Add-Content -Path completeList.html $sbLong.ToString()
Add-Content -Path completeList.html $htmlFooter
