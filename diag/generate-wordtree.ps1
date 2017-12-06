#!/usr/bin/pwsh
$content = Get-Content -Raw -Path "/diag/latest.vm.list" | ConvertFrom-Json

$html_header = 
"<html>
<head>
  <script type=`"text/javascript`" src=`"https://www.gstatic.com/charts/loader.js`"></script>
  <script type=`"text/javascript`">
    google.charts.load('current', {packages:['wordtree']});
    google.charts.setOnLoadCallback(drawSimpleNodeChart);
    function drawSimpleNodeChart() {
      var nodeListData = new google.visualization.arrayToDataTable([
        ['id', 'childLabel', 'parent', 'size', { role: 'style' }],
"
$html_footer = "
      ]);
      var options = {
        colors: ['black', 'black', 'black'],
        wordtree: {
          format: 'explicit',
          type: 'suffix'
        }
      };

      var wordtree = new google.visualization.WordTree(document.getElementById('wordtree_explicit'));
      wordtree.draw(nodeListData, options);

      google.visualization.events.addListener(wordtree, 'select', selectHandler);

      function selectHandler() {
      }

    }
  </script>
</head>
<body>
  <div id=`"wordtree_explicit`" style=`"width: 100%; height: 100%;`"></div>
</body>
</html>
"
#taken from az account location-list on 11.29.2017 with LIS subscription.
#when i use maps, i will update to read the details directly from azure.
$azureLocationNames = @{
    eastasia = "East Asia"
    southeastasia = "Southeast Asia"
    centralus = "Central US"
    eastus = "East US"
    eastus2 = "East US 2"
    westus = "West US"
    northcentralus = "North Central US"
    southcentralus = "South Central US"
    northeurope = "North Europe"
    westeurope = "West Europe"
    japanwest = "Japan West"
    japaneast = "Japan East"
    brazilsouth = "Brazil South"
    australiaeast = "Australia East"
    australiasoutheast = "Australia Southeast"
    southindia = "South India"
    centralindia = "Central India"
    westindia = "West India"
    canadacentral = "Canada Central"
    canadaeast = "Canada East"
    uksouth = "UK South"
    ukwest = "UK West"
    westcentralus = "West Central US"
    westus2 = "West US 2"
    koreacentral = "Korea Central"
    koreasouth = "Korea South"
}

$locationId = -1
$resourceId = -1
$cursor = 0

$lastLocation = ""
$lastResourceGroup = ""

$sb = New-Object System.Text.StringBuilder
$sb.Append("      [0, '#Core', -1, 1, 'black']")


foreach( $vm in $content | Sort-Object -Property location, resourceGroup )
{
  $sb.AppendLine(",") 
  $cursor = $cursor + 1

  $vmName = $vm.name

  $resourceGroup = $vm.resourceGroup

  if( $vm.location -ne $lastLocation )
  {
      #We have a new location.  Create the region and link it to the subscription.
      $sb.AppendLine( "      [$cursor, '$($azureLocationNames[$($vm.location)])', 0, 1, 'black']," )
      $lastLocation = $vm.location
      $lastResourceGroup = ""
      $locationId = $cursor
      $cursor = $cursor + 1
  }
  if( $resourceGroup -ne $lastResourceGroup )
  {
      #We have a new resourceGroup. Create the group and link to our location.
      $sb.AppendLine( "      [$cursor, '$resourceGroup', $locationId, 1, 'blue']," )
      $lastResourceGroup = $resourceGroup
      $resourceId = $cursor
      $cursor = $cursor + 1
  }

    $vmSize = $vm.hardwareProfile.vmSize
    $location = $vm.location

    $coreCount = -1
    $officialSizes = Get-Content -Raw -Path "/diag/vmsizes.$location.json.cache" | ConvertFrom-Json
    if( $officialSizes )
    {
      $officialSize = $officialSizes | where { $_.name -eq $vmSize }
      if( $officialSize )
      {
        $coreCount = $officialSize.numberOfCores
        Write-Host "New size (in cores) $vmSize"
      }
    }
    Write-Host "vmSize = $vmSize"

  if( $coreCount -gt 0 )
  {
    $sb.Append( "      [$cursor, '$vmName', $resourceId, $coreCount, 'green']" )
  }
  else {
    $sb.Append( "      [$cursor, '$vmName -- UNKNOWN SIZE: $vmSize', $resourceId, 1, 'red']" )
    Write-Host "$vmName -- $azureLocation, $resourceGroup -- UNKNOWN OFFICIAL SIZE: $vmSize"
  }
}
Remove-Item -Path wordtree.html

Add-Content -Path wordtree.html $html_header
Add-Content -Path wordtree.html $sb.ToString()
Add-Content -Path wordtree.html $html_footer
