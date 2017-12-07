#!/usr/bin/pwsh
$atticPath = "/diag/attic"
$sizesPath = "/diag"

#Hacky params.  Should iterate with arguments.

$leftFilename = $args[ 0 ]
$rightFilename = $args[ 1 ]

Write-Host "$leftFilename $rightFilename"

if( $leftFilename -and $rightFilename )
{


$leftFile = "$atticPath/$leftFilename"
$rightFile = "$atticPath/$rightFilename"

$leftVMs = Get-Content -Raw -Path $leftFile | ConvertFrom-Json
$rightVMs = Get-Content -Raw -Path $rightFile | ConvertFrom-Json

$leftList = @()
$addedList = @()
$sharedList = @()

$machineRegistry = @{}
$locations = Get-Content -Raw -Path "$sizesPath/az.locations.json.cache" | ConvertFrom-Json
     
$timestamp = "$leftFilename".Split(".")[2]
$date = Get-Date -Date "$($timestamp.Substring(0,4))-$($timestamp.Substring(4,2))-$($timestamp.Substring(6,2)) $($timestamp.Substring(9,2)):$($timestamp.Substring(11,2)):$($timestamp.Substring(13,2))Z"
$timestamp2 = "$rightFilename".Split(".")[2]
$date2 = Get-Date -Date "$($timestamp.Substring(0,4))-$($timestamp.Substring(4,2))-$($timestamp.Substring(6,2)) $($timestamp.Substring(9,2)):$($timestamp.Substring(11,2)):$($timestamp.Substring(13,2))Z"
$leftCoreCount = 0
foreach( $vm in $leftVMs )
{
    $currentLocation = $vm.location.ToLower()   #loc.invariant -- data needs it?
    $vmSize = $vm.hardwareProfile.vmSize

    $officialSizes = Get-Content -Raw -Path "$sizesPath/vmsizes.$currentLocation.json.cache" | ConvertFrom-Json
    $officialSize = $officialSizes | where { $_.name -eq $vmSize } 
    if( $officialSize )
    {
        $vmCores = $officialSize.numberOfCores
        $leftCoreCount += $vmCores
    }        
    
    $vmRecord = @{
        vmid = $vm.vmid
        name = $vm.name
        location = $currentLocation
        vmSize = $vmSize
        numberOfCores = $vmCores
        resourceGroup = $vm.resourceGroup
    }
    $machineRegistry[ $vmRecord.vmid ] = $vmRecord
    $leftList += $vmRecord.vmid
}
foreach( $vm in $rightVMs )
{
    if( $leftList.Contains( $vm.vmid ) )
    {
        $sharedList += $vm.vmid 
        $leftList = $leftList -ne $vm.vmId
    }
    else {
        $currentLocation = $vm.location.ToLower()   #loc.invariant -- data needs it?
        $vmSize = $vm.hardwareProfile.vmSize
    
        $officialSizes = Get-Content -Raw -Path "$sizesPath/vmsizes.$currentLocation.json.cache" | ConvertFrom-Json
        $officialSize = $officialSizes | where { $_.name -eq $vmSize } 
        if( $officialSize )
        {
            $vmCores = $officialSize.numberOfCores
        }        
        
        $vmRecord = @{
            vmid = $vm.vmid
            name = $vm.name
            location = $currentLocation
            vmSize = $vmSize
            numberOfCores = $vmCores
            resourceGroup = $vm.resourceGroup
        }
        $machineRegistry[ $vmRecord.vmid ] = $vmRecord
        $addedList += $vmRecord.vmid
    }
}
Write-Host "Start Date: $date"
Write-Host "End Date: $date2"

Write-Host "Deleted List: $($leftList.Count)"
foreach( $vmid in $leftList )
{
    $vm = $machineRegistry[$vmid]
    Write-Host "Deleted`t$($vm.numberOfCores)`t$($vm.location)`t$($vm.resourceGroup)`t$($vm.name)"
}

Write-Host "Added List: $($addedList.Count)"
foreach( $vmid in $addedList )
{
    $vm = $machineRegistry[$vmid]
    Write-Host "Added`t$($vm.numberOfCores)`t$($vm.location)`t$($vm.resourceGroup)`t$($vm.name)"
}
Write-Host "Shared List: $($sharedList.Count)"
}
else
{
Write-Host "Two arguments. Left and right filename. Just filenames. Path is handled."
}

