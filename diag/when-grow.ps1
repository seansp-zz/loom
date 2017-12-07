#!/usr/bin/pwsh
Write-Host "Looking in the attic to see our vm lists."
$atticPath = "/diag/attic"
$sizesPath = "/diag"

$locations = Get-Content -Raw -Path "/diag/az.locations.json.cache" | ConvertFrom-Json
$vmFiles = Get-ChildItem -Path $atticPath -Filter "vm.list.*.json" | Sort-Object Name 


$fileCount = $vmFiles.Count
$fileIndex = 0;

    foreach( $fileInput in $vmFiles )
    {
        $fileIndex++;
     
        $timestamp = "$($fileInput.name)".Split(".")[2]
        $date = Get-Date -Date "$($timestamp.Substring(0,4))-$($timestamp.Substring(4,2))-$($timestamp.Substring(6,2)) $($timestamp.Substring(9,2)):$($timestamp.Substring(11,2)):$($timestamp.Substring(13,2))Z"
        $coreCount = 0
        $allTheVMs = Get-Content -Raw -Path $($fileInput.FullName) | ConvertFrom-Json
        foreach( $vm in $allTheVMs )
        {
            #record the vmID into our current state.
            #12/6/2017 -- Encountered 'SouthIndia' as location vs 'southindia' as specified.  ToLower() for now.
            $currentLocation = $vm.location.ToLower()   #loc.invariant -- data needs it?
            $vmSize = $vm.hardwareProfile.vmSize
        
            $officialSizes = Get-Content -Raw -Path "$sizesPath/vmsizes.$currentLocation.json.cache" | ConvertFrom-Json
            $officialSize = $officialSizes | where { $_.name -eq $vmSize } 
            if( $officialSize )
            {
                $vmCores = $officialSize.numberOfCores
                $coreCount += $vmCores 
            }        
        }
        Write-Host "$fileIndex/$fileCount $($fileInput.name) -- Time: $date -- Count: $coreCount"
    }
