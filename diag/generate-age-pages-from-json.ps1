$finalResults = Get-Content -Raw -Path "cache.results.json" | ConvertFrom-Json
$sorted = $finalResults | sort { $_.Weight } -Descending

$allocated = $sorted | where { $_.Deallocated -eq $false }



$header = "
<TABLE BORDER=`"2`">
<TR>
  <TH COLSPAN=`"10`">
    <A HREF=`"https://ostcjenkins.westus2.cloudapp.azure.com/view/Utilities/job/Accumulate-Hard-Drive-Ages`">GENERATED</A>
  </TH>
</TR>
<TR>
  <TD>Name</TD>
  <TD>Resource Group</TD>
  <TD>Location</TD>
  <TD>Number of Cores</TD>
  <TD>vmSize</TD>
  <TD>Age in Days</TD>
  <TD>Idle Days (if blob)</TD>
  <TD>Weight = Age * Number of Cores</TD>
  <TD>StorageKind (Blob or Disk)</TD>
  <TD>Deallocated?</TD>
</TR>
"
$footer = "</TABLE>"


#Create the full report.
$stringBuilderFull = New-Object System.Text.StringBuilder
$fullString = "Complete VM List -- $(Get-Date)"
$stringBuilderFull.AppendLine("<HTML>")
$stringBuilderFull.Append( $header.Replace("GENERATED", $fullString ) )
foreach( $vm in $sorted )
{
  $stringBuilderFull.AppendLine( "
  <TR>
    <TD><A HREF=`"https://ms.portal.azure.com/#resource/subscriptions/2cd20493-fe97-42ef-9ace-ab95b63d82c4/resourceGroups/$($vm.resourceGroup)/providers/Microsoft.Compute/virtualMachines/$($vm.Name)/overview`">$($vm.Name)</A></TD>
    <TD>$($vm.resourceGroup)</TD>
    <TD>$($vm.location)</TD>
    <TD>$($vm.coreCount)</TD>
    <TD>$($vm.vmSize)</TD>
    <TD>$($vm.Age)</TD>
    <TD>$($vm.Idle)</TD>
    <TD>$($vm.Weight)</TD>
    <TD>$($vm.StorageKind)</TD>
    <TD>$($vm.Deallocated)</TD>
" )
}
$stringBuilderFull.AppendLine( $footer )
$stringBuilderFull.AppendLine( "</HTML>" )
Set-Content -Path "fullreport.html" -Value $stringBuilderFull.ToString()

#Create the full report.
$stringBuilderAlloc = New-Object System.Text.StringBuilder
$fullString = "Allocated VM List -- $(Get-Date)"
$stringBuilderAlloc.AppendLine("<HTML>")
$stringBuilderAlloc.Append( $header.Replace("GENERATED", $fullString ) )
foreach( $vm in $allocated )
{
  $stringBuilderAlloc.AppendLine( "
  <TR>
    <TD><A HREF=`"https://ms.portal.azure.com/#resource/subscriptions/2cd20493-fe97-42ef-9ace-ab95b63d82c4/resourceGroups/$($vm.resourceGroup)/providers/Microsoft.Compute/virtualMachines/$($vm.Name)/overview`">$($vm.Name)</A></TD>
    <TD>$($vm.resourceGroup)</TD>
    <TD>$($vm.location)</TD>
    <TD>$($vm.coreCount)</TD>
    <TD>$($vm.vmSize)</TD>
    <TD>$($vm.Age)</TD>
    <TD>$($vm.Idle)</TD>
    <TD>$($vm.Weight)</TD>
    <TD>$($vm.StorageKind)</TD>
    <TD>$($vm.Deallocated)</TD>
" )
}
$stringBuilderAlloc.AppendLine( $footer )
$stringBuilderAlloc.AppendLine( "</HTML>" )
Set-Content -Path "allocatedreport.html" -Value $stringBuilderAlloc.ToString()

#Create the TOP 100 report.
$stringBuilderTop = New-Object System.Text.StringBuilder
$fullString = "Top 100 VM List -- $(Get-Date)"
$stringBuilderTop.AppendLine("<HTML>")
$stringBuilderTop.Append( $header.Replace("GENERATED", $fullString ) )
$countStop = 100

foreach( $vm in $allocated )
{
  $countStop--
  if( $countStop -lt 0 )
  {
    break
  }

  $stringBuilderTop.AppendLine( "
  <TR>
    <TD><A HREF=`"https://ms.portal.azure.com/#resource/subscriptions/2cd20493-fe97-42ef-9ace-ab95b63d82c4/resourceGroups/$($vm.resourceGroup)/providers/Microsoft.Compute/virtualMachines/$($vm.Name)/overview`">$($vm.Name)</A></TD>
    <TD>$($vm.resourceGroup)</TD>
    <TD>$($vm.location)</TD>
    <TD>$($vm.coreCount)</TD>
    <TD>$($vm.vmSize)</TD>
    <TD>$($vm.Age)</TD>
    <TD>$($vm.Idle)</TD>
    <TD>$($vm.Weight)</TD>
    <TD>$($vm.StorageKind)</TD>
    <TD>$($vm.Deallocated)</TD>
" )
}
$stringBuilderTop.AppendLine( $footer )
$stringBuilderTop.AppendLine( "</HTML>" )
Set-Content -Path "top100report.html" -Value $stringBuilderTop.ToString()
