# SF-scripts
Handy SolidFire Scripts

These are NOT production ready scripts, but are intended to provide basic demonstration of the possibilities of the SolidFire PowerShell Module for real-world use-cases
- find_my_sf_vols.ps1 - PowerShell script to run on a Windows host to identify attached SolidFire LUNs (attached via FC and/or iSCSI)
- sf_faults_to_smtp.ps1 - PowerShell script to email SF cluster faults out thru local SMTP server (e.g. for "dark sites")

2019-01-31
- hci_ipmi.sh - Bash script for performing some handy functions from the command-line - especially useful for demo/eval kit where frequent power-control/status is performed. Also includes "inventory" and node-identity LED control.

Usage: ./hci_ipmi.sh [ <IPMI_IP> ] [ powerStatus | powerOn | powerCycle | powerOff | rebootFromUSB | inventory | blinkOn | blinkOff ]
             note: rebootFromUSB will act on Compute nodes only
