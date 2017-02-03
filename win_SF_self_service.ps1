#
##########################################################################
# Sample script to provision new vol and attach it to the host running it
##########################################################################
#
# 2017-02-01 Richard Shepherd (NetApp SolidFire)
#
# this script is *not* production-ready!!
# - more error-checking is required, e.g.:
#   - that vol-names not already in use on SF cluster before creation?
#   - that drive-letters are not already in-use on the host?
#   - return values/output of each call should be checked
# - some pauses are required to allow background-tasks (e.g. host-storage rescans) to complete
# - before further tasks are begun (e.g. formatting partitions!)
# - additionally the input should be moved out to command-line, and generalized to handle different numbers of vols
# 
# in-Summary: the intention is to show what can be done, as an example of creating custom workflows
#  It's the user's responsibility to understand what this script is doing!
#
# Requirements:
# - PowerShell installed (is default on later versions of Windows)
# - Windows 2012+ host (not yest tested/verified on Win 2k8)
# - SolidFire PowerShell modules is installed
# - user is logged into Windows host with local-admin rights (e.g. any local-admin or Domain-admin user)
# - SolidFire Cluster management IP (MVIP) and admin credentials available
#
# Note that this workflow performs operations on both the storage-cluster (e.g. Get-SF*, Set-SF*) as well as
#  operations on the local-host. Hence it's not possible to translate this entire workflow into SF API calls-only
#  as the SF cluster has no ability to perform operations on specific hosts
#
# Load the modules for iSCSI and SolidFire Cluster management
import-module iSCSI
import-module SolidFire
#
# Connect to the cluster
#  replace the IP below with your cluster MVIP
$SFcluster = "10.1.1.100"
Connect-SFCluster -target $SFcluster -username "admin" -password "solidfire"
$svip = (Get-SFClusterInfo).Svip
$svip
#
# or, replace the above login with this to avoid hard-coded credentials
#  instead you will be prompted for credentials each time you run this:
#Connect-SFCluster -target $SFcluster -credential $(get-credential)
#
###################################
# user-input - from here
$newAccount = "richardacc"
$newVag     = "richardvag"
#
$newVol1_name = "richardvol1"
$newVol1_size = 5
$newVol1_drive = "R"
#
$newVol2_name = "richardvol2"
$newVol2_size = 13
$newVol2_drive = "S"
# - to here
###################################
#
# View volumes on the host before beginning:

Get-Disk   | ft
Get-Partition | ft
Get-Volume | ft

# Create SF account (i.e. customer / client)

Get-SFAccount | ft
$newAccount_details = new-sfaccount -username $newAccount
Get-SFAccount | ft
$newAccountID = $newAccount_details.AccountID
$newAccountID

# Create SF Volume-Access-Group (VAG) for this client's host(s)

Get-SFVolumeAccessGroup | ft
$newVag = New-SFVolumeAccessGroup -name $newVag
Get-SFVolumeAccessGroup | ft
$vagId = $newVag.VolumeAccessGroupID
$vagId

# Add this host to the VAG
$myIqn = (Get-InitiatorPort).NodeAddress
$myIqn

Add-SFInitiatorToVolumeAccessGroup -VolumeAccessGroup $vagID -initiators $myIqn
Get-SFVolumeAccessGroup | ft

# Create new volumes for this host

$newVol1_details = new-SFVolume -name $newVol1_name -TotalSize $newVol1_size -GB -accountID $newAccountID -enable512e $true 
$newVol1_details
$newVol1_ID = $newVol1_details.volumeID
$newVol1_serial = $newVol1_details.ScsiEUIDeviceID
#
$newVol2_details = new-SFVolume -name $newVol2_name -TotalSize $newVol2_size -GB -accountID $newAccountID -enable512e $true
$newVol2_details
$newVol2_ID = $newVol2_details.volumeID
$newVol2_serial = $newVol2_details.ScsiEUIDeviceID

# Add these to the VAG

Add-SFVolumeToVolumeAccessGroup -volumeAccessGroupID $vagId -volumeID $newVol1_ID
Add-SFVolumeToVolumeAccessGroup -volumeAccessGroupID $vagId -volumeID $newVol2_ID
Get-SFVolumeAccessGroup | ft
# ensure the above is complete before proceeding to scan/connect from the host in the below
#
# scan for these new vols on the host
Get-IscsiTargetPortal | ft
Get-IscsiTarget | ft
New-IscsiTargetPortal -TargetPortalAddress $svip 
Get-IscsiTargetPortal | ft
Get-IscsiTarget | ft
Get-IscsiTarget | foreach { $volIqn = $_.nodeAddress ; Connect-IscsiTarget -TargetPortalAddress $svip -IsMultiPathEnabled $True -IsPersistent $True -NodeAddress $volIqn }
Get-IscsiConnection | ft
Get-IscsiSession | ft

# View volumes on the host:

Get-Disk   | ft
Get-Partition | ft
Get-Volume | ft
$allDisks = Get-Disk

# match the new disk with our SF vols
$allDisks | foreach { if ($_.SerialNumber -eq $newVol1_serial) { $newDisk1 = $_ } }
$allDisks | foreach { if ($_.SerialNumber -eq $newVol2_serial) { $newDisk2 = $_ } }
$newDisk1_id = $newDisk1.number
$newDisk2_id = $newDisk2.number

# online the new Luns and create filesystem & mount at the drive letters
#  may need some pauses between the following lines to allow time for completion of each task before beginning the next...
Set-Disk -number $newDisk1_id -IsOffline $False 
Set-Disk -number $newDisk1_id -IsReadOnly $False
Initialize-Disk -number $newDisk1_id -PartitionStyle MBR -Confirm:$False
$newPart1 = New-Partition -DiskNumber $newDisk1_id -DriveLetter $newVol1_drive -UseMaximumSize
Format-Volume -DriveLetter $newVol1_drive -FileSystem NTFS -Confirm:$False

Set-Disk -number $newDisk2_id -IsOffline $False
Set-Disk -number $newDisk2_id -IsReadOnly $False
Initialize-Disk -number $newDisk2_id -PartitionStyle MBR -Confirm:$False
$newPart2 = New-Partition -DiskNumber $newDisk2_id -DriveLetter $newVol2_drive -UseMaximumSize
Format-Volume -DriveLetter $newVol2_drive -FileSystem NTFS -Confirm:$False

# View volumes on the host:

Get-Disk   | ft
Get-Partition | ft
Get-Volume | ft

#### Optional Extra 1: Resize Volume and access the new space on the host
###Set-SFVolume -VolumeID $newVol1_ID -TotalSize 7 -GB -Confirm:$False
###Update-HostStorageCache
###Get-Disk | ft
###$newPart1_size = (Get-PartitionSupportedSize –DiskNumber $newDisk1_id -PartitionNumber 1).SizeMax
###Resize-Partition -DiskNumber $newDisk1_id -Partition 1 -size $newPart1_size

#### Optional Extra 2: Alter the QoS setting
###Get-SFDefaultQoS
###Get-SFVolume -VolumeID $newVol1_ID
###Set-SFVolume -VolumeID $newVol1_ID -MinIOPS 200 -MaxIOPS 500 -BurstIOPS 1500 -Confirm:$False
###Get-SFVolume -VolumeID $newVol1_ID

###Get-Disk   | ft
###Get-Partition | ft
###Get-Volume | ft

#
# EOF
#
