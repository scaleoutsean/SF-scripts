#
# PowerShell: basic script to find faults in an SF cluster & email to local admin
#
# 2016-12-19 Richard Shepherd (NetApp SF), find unresolved faults from an SF cluster and email to local admin
#                                          useful in case of "secure/dark site" where the m-node cannot send
#                                          directly to ActiveIQ, and when no local SNMP monitoring system available
#
# Edit the below section for your local values
###############################################
$mySFCluster = "sf-mvip.demo.netapp.com"
$mySFAdmin = "admin"
$mySFPasswd = "Netapp1!"
#
$mySMTPserver = "smtp.corp.netapp.com"
$mySender = "SFmonitor@netapp.com"
$myLocalAdmin = "richard.shepherd3@netapp.com"
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
# for unattended use
Connect-SFCluster -Target $mySFCluster -Username $mySFAdmin -Password $mySFPasswd
# or, for interactive script-use
###Connect-SFCluster -Target $mySFCluster -credential $(get-credential)
$sfName = $(Get-SFClusterInfo).Name
$sfFaults = Get-SFClusterFault -FaultType current
$numFaults = $sfFaults.count
$msgBody = "`n"
if ($numFaults -gt 0) {
 $title += "Found $numFaults faults in SF cluster $sfName"
 $underLine = ""
 foreach ($char in 1..$title.Length) {
  $underLine += "-"
 }
 $msgBody += "$title`n"
 $msgBody += "$underLine`n"

 foreach ($fault in $sfFaults) {
  ###$formattedDate = "{0:dd-MM-yyyy hh:mm:ss}" -f $fault.Date
  # not-so-pretty way to re-write the timestamp
  $formattedDate = ""
  foreach ($ind in 0..15) {
   $char = $fault.Date.ToString().Chars($ind)
   if ($char -eq "T") {
    $char = " "
   }
   $formattedDate += $char
  }
  $fault | Add-Member -NotePropertyName DateStamp -NotePropertyValue $formattedDate
 }
 $msgBody += $sfFaults | Format-Table DateStamp,Severity,Code,Details -AutoSize | Out-String
 # comment out the below line if using non-interactively
 $msgBody
 #
 # Email out
 $mySubject = "SF Cluster $mySFName Faults"
 # uncomment the below line if you have a working SMTP server to deliver to
 Send-MailMessage -From $mySender -To $myLocalAdmin -Subject $mySubject -SmtpServer $mySMTPserver -Body $msgBody
 #
} else {
 $title = "Good news: No faults found in SF cluster $sfName"
 $underLine = ""
 foreach ($char in 1..$title.Length) {
  $underLine += "-"
 }
 $title
 $underLine
}
#
# EOF
#
