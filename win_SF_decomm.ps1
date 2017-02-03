#
##########################################################################
# Sample script to cleanup all SF vols from windows host
##########################################################################
#
# 2017-02-01 Richard Shepherd (NetApp SolidFire)
#
# this script is *not* production-ready!!
#  see the comments in the accompanying self_service script - they apply here also :-)
#   and of course this script does a lot of destructive stuff (deleting vols, in particular!)
#   so *caution* required
#
# Load the modules for iSCSI and SolidFire Cluster management
import-module iSCSI
import-module SolidFire
#
# Connect to the cluster
$SFcluster = "10.1.1.100"
Connect-SFCluster -target $SFcluster -username "admin" -password "solidfire"
$svip = (Get-SFClusterInfo).Svip
$svip
#
# or, replace the above login with this to avoid hard-coded credentials
#  instead you will be prompted for credentials each time you run this:
#Connect-SFCluster -target $SFcluster -credential $(get-credential)
#
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
#
# View volumes on the host before beginning:

Get-Disk   | ft
Get-Partition | ft
Get-Volume | ft

################################################################################
# Cleanup:
#
# Remove the iSCSI connections
get-iscsitarget | ft
get-iscsitarget | foreach { $voliqn = $_.NodeAddress ; Disconnect-IscsiTarget -NodeAddress $voliqn -Confirm:$False }
get-iscsitarget | ft

# Remove the host initiator from the VAG
$vagID = $(Get-SFVolumeAccessGroup -Name $newVag).VolumeAccessGroupID
$myIqn = (Get-InitiatorPort).NodeAddress
$myIqn

Remove-SFInitiatorFromVolumeAccessGroup -VolumeAccessGroupID $vagID -initiators $myIqn -Confirm:$False
Get-IscsiTargetPortal | foreach { Update-IscsiTarget -iSCSITargetPortal $_ }
# Remove the iSCSI target portal

Get-IscsiTargetPortal | ft
Remove-IscsiTargetPortal -TargetPortalAddress $svip -Confirm:$False
Get-IscsiTargetPortal | ft
get-iscsitarget | ft

# delete the volumes:
Get-SFVolume | ft
$newVol1_ID = $(Get-SFVolume -Name $newVol1).VolumeID
$newVol2_ID = $(Get-SFVolume -Name $newVol2).VolumeID
Remove-SFVolume -volumeID $newVol1_ID -confirm:$False
Remove-SFVolume -volumeID $newVol2_ID -confirm:$False
Remove-SFDeletedVolume -volumeID $newVol1_ID -confirm:$False
Remove-SFDeletedVolume -volumeID $newVol2_ID -confirm:$False
Get-SFVolume -includeDeleted | ft

# delete the VAG
Get-SFVolumeAccessGroup | ft
Remove-SFVolumeAccessGroup -VolumeAccessGroupID $vagID -confirm:$False
Get-SFVolumeAccessGroup | ft

# delete the account
Get-SFAccount | ft
$newAccountID = (Get-SFAccount -username $newAccount).AccountID
Remove-SFAccount -accountID $newAccountID -confirm:$False
Get-SFAccount | ft
#
# EOF
#
