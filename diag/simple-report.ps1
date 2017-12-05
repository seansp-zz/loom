#!/usr/bin/pwsh
$content = Get-Content -Raw -Path "/diag/latest.vm.list" | ConvertFrom-Json
$finalCount = 0
$lastResourceGroup

foreach( $vm in $content | Sort-Object -Property resourceGroup )
{
    $finalCount += 1
    $computerName = $vm.name
    $azureLocation = $vm.location
    $vmSize = $vm.hardwareProfile.vmSize
    $resourceGroup = $vm.resourceGroup
    $vmid = $vm.vmid    

    if( $resourceGroup -ne $lastResourceGroup )
    {
        Write-Host "[[ $resourceGroup ]]"
        $lastResourceGroup = $resourceGroup
    }

    Write-Host "[$finalCount] $computerName,$resourceGroup,$azureLocation,$vmSize,$vmid"
}
Write-Host "Final count == $finalCount"

