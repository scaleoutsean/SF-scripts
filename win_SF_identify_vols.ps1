#
# PowerShell: basic script to identify which SF LUNs are locally attached
#
# 2016-12-15 Richard Shepherd (NetApp SF), show which of our disks are SF volumes, and their name, size & drive-letter
#                                          storage-protocol independent - should be useful for FC-attached hosts and work
#                                          the same for iSCSI-attached LUNs
#
# Edit the below to be the name-or-IP of your SF Cluster
###############################################
$mySFCluster = "sf-mvip.demo.netapp.com"
###############################################
# no further site-specific edits required
#
# check that we have the module available
$haveModule = Get-Module -ListAvailable SolidFire
if ($haveModule -eq $null) {
 write-error "NetApp SolidFire PowerShell module is not available, cannot continue"
 exit
}
#
import-module SolidFire
connect-SFCluster -credential $(get-credential) -target $mySFCluster 
$sfVols = Get-SFVolume 
$disks = Get-Disk
$parts = Get-Partition
#
foreach ($vol in $sfVols) {
 $volName = $vol.Name
 $volSize = $vol.TotalSize
 $volNAA = $vol.ScsiNAADeviceID
 foreach ($disk in $disks) {
  $diskID = $disk.UniqueId
  $diskPath = $disk.Path
  if ($diskID -eq $volNAA) {
   $size = $volSize / 1000000000
   $size = "{0:N0}" -f $size
   "Found SolidFire volume = $volName, size = $size GB, NAA = $volNAA"
   $mounted = $false
   foreach ($part in $parts) {
    $partDiskId = $part.DiskId
    $partDrive = $part.DriveLetter
    if ($partDiskId -eq $diskPath) {
     " mounted as Drive = $partDrive"
     $mounted = $true
     break
    }
   }
   if (!$mounted) {
    " not mounted at a drive-letter"
   }
  }
 }
}
#
# EOF
#
