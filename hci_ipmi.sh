#!/bin/bash
#
# use the IPMItool to do CLI rebboots etc.
#
# How to use:
#  1. Download the SMCIPMITool package from e.g. Take the link to download from https://www.supermicro.com/en/solutions/management-software/ipmi-utilities
#  2. Unpack it somewhere on a Linux VM (for convenience)
#  3. place this script somewhere in your PATH, and edit the section below for your site
#  4. run it...
#
# Sample usage/output:
#
# ./hci_ipmi.sh 
# Usage: ./hci_ipmi.sh [ <IPMI_IP> ] [ powerStatus | powerOn | powerCycle | powerOff | rebootFromUSB | inventory | blinkOn | blinkOff ]
#             note: rebootFromUSB will act on Compute nodes only 
#
# ./hci_ipmi.sh inventory
# IPMI IP          | Chassis Serial # | Slot (view-from front / rear)  | Node Serial # | Model
# 10.255.1.51      | 221809001830     | C    (lower     right / left ) | 221808001675  | H300E
# 10.255.1.52      | 221808001674     | A    (lower     left  / right) | 221808001714  | H300E
# 10.255.1.53      | 221809001830     | A    (lower     left  / right) | 221752000130  | H300S
# 10.255.1.54      | 221809001830     | B    (upper     left  / right) | 221808001751  | H300S
# 10.255.1.55      | 221808001674     | C    (lower     right / left ) | 221808001752  | H300S
# 10.255.1.56      | 221808001674     | D    (upper     right / left ) | 221808001753  | H300S
#
# ./hci_ipmi.sh 10.255.1.54 powerStatus
# 10.255.1.54: Power is currently off.
#
USAGE="Usage: $0 [ <IPMI_IP> ] [ powerStatus | powerOn | powerCycle | powerOff | rebootFromUSB | inventory | blinkOn | blinkOff ]
             note: rebootFromUSB will act on Compute nodes only " 
#
####################################################################
# Edit the below for your site...
#
ipmiUser="ADMIN"
ipmiPass="ADMIN"
PATH=~/SMCIPMITool_2.21.0_build.181029_bundleJRE_Linux_x64:$PATH
#
IPMITOOL=SMCIPMITool_2.21.0_build.181029_bundleJRE_Linux_x64/SMCIPMITool

# Sydney/Canberra HCI demo kit
#IPMI_IPS='10.255.1.46 10.255.1.40 10.255.1.49 10.255.1.42 10.255.1.33 10.255.1.10'
# Singapore HCI demo kit
IPMI_IPS='10.255.1.51 10.255.1.52 10.255.1.53 10.255.1.54 10.255.1.55 10.255.1.56'
#
# ...up to here
####################################################################

[ -x $IPMITOOL ] || {
 echo "IPMItool binary not executable: $IPMITOOL - exiting"
 exit 1
}

COMPUTE_NODES=""
STORAGE_NODES=""

identifyNodeTypes () {
 # identify the compute & storage separately
 echo "Finding type of each node..."
 for IP in $IPMI_IPS
 do
  product=$($IPMITOOL $IP $ipmiUser $ipmiPass ipmi fru | grep 'Product Name' | tail -1 | awk '{ print $5 }')
  case $product in
   *0E) COMPUTE_NODES="$COMPUTE_NODES $IP" ;;
   *0S) STORAGE_NODES="$STORAGE_NODES $IP" ;;
  esac
 done
 #
 echo "Compute Nodes IPMI = $COMPUTE_NODES"
 echo "Storage Nodes IPMI = $STORAGE_NODES"
}
#
# Remove the # below to force this for all node-types (which would require USB Keys to be present in all...)
#
rebootFromUsbKey () {
 for IP in $COMPUTE_NODES # $STORAGE_NODES
 # Find the USB KEY boot-option-index
 do
  USB_STRING=$($IPMITOOL $IP $ipmiUser $ipmiPass ipmi power bootoption | grep -i 'usb key' | grep -vi uefi | sed -e 's/\s+/ /g')
  read -r -a ARRAY <<< "$USB_STRING"
  for index in "${!ARRAY[@]}"
  do
   element=${ARRAY[index]}
   nextElement=${ARRAY[$(( $index + 1 ))]}
   if [ "$element" = 'USB' -a "$nextElement" = "KEY" ]
   then
    USB_INDEX="${ARRAY[$(( $index - 1 ))]}"
    # strip any trailing colon
    USB_INDEX=$(echo $USB_INDEX | cut -d ':' -f 1)
    echo "$IP: USB Key index is $USB_INDEX"
    # set the boot option to USB Key on next boot
    $IPMITOOL $IP $ipmiUser $ipmiPass ipmi power bootoption $USB_INDEX
    echo "Power-cycling $IP"
    $IPMITOOL $IP $ipmiUser $ipmiPass ipmi power reset
   fi
  done
 done
}

powerStatus () {
 for IP in $IPMI_IPS
 do
  echo "$IP: $($IPMITOOL $IP $ipmiUser $ipmiPass ipmi power status)"
 done
}

powerOn () {
 for IP in $IPMI_IPS
 do
  echo "$IP: $($IPMITOOL $IP $ipmiUser $ipmiPass ipmi power up)"
 done
}

powerCycle () {
 for IP in $IPMI_IPS
 do
  echo "$IP: $($IPMITOOL $IP $ipmiUser $ipmiPass ipmi power reset)"
 done
}

powerOff () {
 for IP in $IPMI_IPS
 do
  echo "$IP: $($IPMITOOL $IP $ipmiUser $ipmiPass ipmi power down)"
 done
}

inventory () {
 echo "IPMI IP          | Chassis Serial # | Slot (view-from front / rear)  | Node Serial # | Model"
 for IP in $IPMI_IPS
 do
  FRU=$($IPMITOOL $IP $ipmiUser $ipmiPass ipmi fru 2>&1)
  chassisSerial=$(echo "$FRU"         | grep 'Chassis Serial Number' | cut -f2 -d '=')
  nodeSlot=$(     echo $chassisSerial | cut -f2 -d '(' | cut -f1 -d ')')
  chassisSerial=$(echo $chassisSerial | cut -f1 -d '(')
  nodeSerial=$(   echo "$FRU"         | grep 'Product Serial Number' | cut -f2 -d '=')
  nodeModel=$(    echo "$FRU"         | grep 'Product Name'| tail -1 | cut -f2 -d '=')
  # add an explanatory to the node-slot
  case $nodeSlot in
   A) slotLocation="lower     left  / right" ;;
   B) slotLocation="upper     left  / right" ;;
   C) slotLocation="lower     right / left " ;;
   D) slotLocation="upper     right / left " ;;
   *) slotLocation="unknown" ;;
  esac
  echo "$(printf '%-16s' $IP) | $chassisSerial     | $nodeSlot    ($slotLocation) |$nodeSerial  |$nodeModel"
 done
}

blinkNodeLed () {
# node=$1
 status=$1
 case $status in
  blinkOn) value=on ;;
  blinkOff) value=off ;;
  *) echo "$USAGE" ; exit 1 ;;
 esac
 for IP in $IPMI_IPS
 do
  $IPMITOOL $IP $ipmiUser $ipmiPass ipmi oem uid $value
 done
}

####################################################################
# Main begins here

[ -z "$1" ] && {
 echo "$USAGE"
 exit 1
}

# check for single-node, rather than all
case "$1" in
 1*|2*|3*|4*|5*|6*|7*|8*|9*) 
  IPMI_IPS=$1
  shift ;;
esac

case "$1" in
 powerStatus)   powerStatus ;;
 powerOn)       powerOn ;;
 powerCycle)    powerCycle ;;
 powerOff)      powerOff ;;
 rebootFromUSB) 
  identifyNodeTypes
  rebootFromUsbKey
  ;;
 inventory)     inventory ;;
 blink*)        blinkNodeLed $1 ;;
 *)             echo "$USAGE" ; exit 1 ;;
esac

#
# EOF
#
