#!/usr/bin/pwsh
Write-Host "Looking in the attic to see our vm lists."
$atticPath = "/diag/attic"
$sizesPath = "/diag"


$htmlHeader = "
<html>
<head>
  <script type=`"text/javascript`" src=`"https://www.gstatic.com/charts/loader.js`"></script>
  <script type='text/javascript'>
    google.charts.load('current', {'packages':['annotationchart']});
    google.charts.setOnLoadCallback(drawChart);

    function drawChart() {
      var data = new google.visualization.DataTable();
      data.addColumn('date', 'Date');
"
$htmlFooter = "
        var chart = new google.visualization.AnnotationChart(document.getElementById('chart_div'));
        var options = {
          displayAnnotations: true
        };

        chart.draw(data, options);
      }
    </script>
  </head>

  <body>
    <div id='chart_div' style='width: 100%; height: 100%;'></div>
  </body>
</html>
"


$locations = Get-Content -Raw -Path "$sizesPath/az.locations.json.cache" | ConvertFrom-Json
$vmFiles = Get-ChildItem -Path $atticPath -Filter "vm.list.*.json" | Sort-Object Name 


$sb = New-Object System.Text.StringBuilder
foreach( $loc in $locations )
{
    $sb.Append("        data.addColumn('number', '$($loc.DisplayName)');`n")
}
    $sb.Append("        data.addRows([`n")

$prevState = @()
$baseline = $true
$vmDictionary = @{}

$fileCount = $vmFiles.Count
$fileIndex = 0

foreach( $fileInput in $vmFiles )
{
    $fileIndex++
    Write-Host "Processing $fileIndex of $fileCount"
 
    $timestamp = "$($fileInput.name)".Split(".")[2]
    $date = Get-Date -Date "$($timestamp.Substring(0,4))-$($timestamp.Substring(4,2))-$($timestamp.Substring(6,2)) $($timestamp.Substring(9,2)):$($timestamp.Substring(11,2)):$($timestamp.Substring(13,2))Z"
    $dateConstructor = "new Date( $($date.Year),$($date.Month),$($date.Day),$($date.Hour),$($date.Minute),$($date.Second), $($date.Millisecond))"
    Write-Host "File date: $date"
    $coreCounts = @{}
    foreach( $loc in $locations )
    {
        $coreCounts[ $loc.name ] = 0
    }
    $coreCount = 0
    $allTheVMs = Get-Content -Raw -Path $($fileInput.FullName) | ConvertFrom-Json
    $currentState = @()
    Write-Host "-PrevState: $($prevState.Count)"
    Write-Host "-CurrentState: $($currentState.Count)"
    foreach( $vm in $allTheVMs )
    {
        #record the vmID into our current state.
        $currentState += $vm.vmid
        #12/6/2017 -- Encountered 'SouthIndia' as location vs 'southindia' as specified.  ToLower() for now.
        $currentLocation = $vm.location.ToLower()   #loc.invariant -- data needs it?
        $vmSize = $vm.hardwareProfile.vmSize

        $officialSizes = Get-Content -Raw -Path "$sizesPath/vmsizes.$currentLocation.json.cache" | ConvertFrom-Json
        $officialSize = $officialSizes | where { $_.name -eq $vmSize } 
        if( $officialSize )
        {
            $vmCores = $officialSize.numberOfCores
            $coreCount += $vmCores 
            $coreCounts[ $currentLocation ] = $coreCounts[ $currentLocation ] + $vmCores
        }
        if( $vmDictionary.ContainsKey( $vm.vmid ) -ne $true )
        {
            $vmDictionary.Set_Item( $vm.vmid, $vm )
            Write-Host -ForegroundColor Cyan "Added $($vm.name) of size $($vm.hardwareProfile.vmSize)[$vmCores] to $($vm.resourceGroup) in $($vm.location)"
        }
        if( $prevState.Contains( $vm.vmid ) )
        {
            $prevState = $prevState -ne $vm.vmid
            $vmDictionary.Remove( $vm.vmid )
        }
    }
    if( $baseline -eq $true )
    {
        $baseline = $false
    }
    else {
        foreach( $vmid in $prevState )
        {
            $vm = $vmDictionary[$vmid]
            Write-Host -ForegroundColor Red "Deleted $($vm.name) of size $($vm.hardwareProfile.vmSize)[$vmCores] to $($vm.resourceGroup) in $($vm.location)"
        }
    }
    $prevState = $currentState
    Write-Host "PrevState    : $($prevState.Count)"
    Write-Host "CurrentState : $($currentState.Count)"
    Write-Host "VM Count     : $($allTheVMs.Count)"
    Write-Host "CoreCount    : $coreCount" 

    $sb.Append( "      [ $dateConstructor ")
    foreach( $loc in $locations )
    {
        $sb.Append( ", $($coreCounts[$loc.name])") 
    }
    $sb.Append( "],`n")
}
$sb.Append( "]);")

Write-Host "We retrieved $($vmFiles.Count)"

Remove-Item -Path timeline.html

Add-Content -Path timeline.html $htmlHeader
Add-Content -Path timeline.html $sb.ToString()
Add-Content -Path timeline.html $htmlFooter
