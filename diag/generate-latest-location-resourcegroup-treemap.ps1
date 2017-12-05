#!/usr/bin/pwsh
$content = Get-Content -Raw -Path "/diag/latest.vm.list" | ConvertFrom-Json
$finalCount = 0
$lastResourceGroup

$azureLocations = @{}

$resourceGroups = @{}


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

foreach( $vm in $content | Sort-Object -Property resourceGroup )
{
    $computerName = $vm.name
    $azureLocation = $vm.location
    $resourceGroup = $vm.resourceGroup

    $resourceGroupFakeName = "$azureLocation-$resourceGroup"
    if( $resourceGroups.ContainsKey( $resourceGroupFakeName ) )
    {
        $resourceGroups[ $resourceGroupFakeName ].vmCount++
        $newrg = $resourceGroups[ $resourceGroupFakeName ]
        Write-Host "XXXXXX $($newrg.rgName) - $($newrg.rgLocation) - $($newrg.vmCount)"
   
    } 
    else {
        $newrg = @{
            vmCount = 1
            rgName = $resourceGroup
            rgLocation = $azureLocation
        }
        Write-Host "YYYYYY $($newrg.rgName) - $($newrg.rgLocation) - $($newrg.vmCount)"
        $resourceGroups[ $resourceGroupFakeName ] = $newrg
    }


    if( $azureLocations.ContainsKey( $azureLocation ) ) {
        $azureLocations[ $azureLocation ] = $azureLocations[ $azureLocation ] + 1
    }
    else {
        $azureLocations[ $azureLocation ] = 1   
    }

    Write-Host "$azureLocation -- $($azureLocations[$azureLocation])"
    $finalCount += 1
}
Write-Host "Final count == $finalCount"
#Create data table for the treemap chart.
$stringbuilder = New-Object System.Text.StringBuilder
$stringbuilder.AppendLine( "var data = google.visualization.arrayToDataTable([")
$stringbuilder.AppendLine( "    ['Location', 'Parent', 'Number of VMs', '']," )
$stringbuilder.Append( "    ['Global', null, 0,0 ]" );

foreach( $lokey in $azureLocationNames.Keys )
{
    $stringbuilder.AppendLine(",")
    Write-Host "$($azureLocationNames[$lokey]) == $($azureLocations[ $lokey ])"
    $stringbuilder.Append( "    ['$($azureLocationNames[$lokey])', 'Global', $($azureLocations[$lokey]), 0]" )
}
foreach( $fakeName in $resourceGroups.Keys )
{
    Write-Host "@@@@@@@ $fakeName"
    $newrg = $resourceGroups[$fakeName]
    Write-Host "ZZZZZZ $($newrg.rgName) - $($newrg.rgLocation) - $($newrg.vmCount)"
    
    $relocation = $resourceGroups[$fakeName].rgLocation
    $rename = $resourceGroups[$fakeName].rgName
    $recount = $resourceGroups[$fakeName].vmCount
    $prettyName = $azureLocationNames[ $relocation ]

    $stringbuilder.AppendLine(",")
    $stringbuilder.Append( "    ['$rename ($relocation)', '$prettyName', $recount, 0]" )
}
$stringbuilder.AppendLine( "  ]);" )
Write-Host "Yay --------------------- "
$outputString = $stringbuilder.ToString()

Write-Host -ForegroundColor Yellow "REsult: $outputString"

Add-Content dataoutput.txt $stringbuilder.ToString()


