<#
#Info: Powershell script to install sysmon on a computer

** IMPORTANT **
1) Create a Sysmon folder with the SYSVOL share on your domain controller
2) Download Sysmon from Microsoft and place both sysmon.exe and sysmon64.exe in
   newly created Sysmon folder
3) Download a sample sysmon config from SwiftOnSecurity, rename the file to
   sysmonConfig.xml and place it within the Sysmon folder. 
   You can also use sysmonconfig.xml from Purpleteaming GitHub
   https://github.com/DefensiveOrigins/APT06202001/tree/master/Lab-Sysmon/sysmon-modular-master
4) Enter the appropriate values for your DC and FQDN below.
5) Create a GPO that will launch this batch file on startup.
6) Apply the GPO to your specified OUs. 
#>

$DC="dc01.lab.internal.local"
$FQDN="lab.internal.local"

#Determine architecture to set Arch Type for the SYSMON Binary

if (test-path "C:\Program Files (x86)") {
    $BINARCH="Sysmon64.exe"
    $SERVBINARCH="Sysmon64"} 
else {
    $BINARCH="Sysmon.exe"
    $SERVBINARCH="Sysmon"}

$SYSMONDIR="C:\windows\sysmon"
$SYSMONBIN="$SYSMONDIR\$BINARCH"
$SYSMONCONFIG="$SYSMONDIR\SysmonConfig.xml"

$GLBSYSMONBIN="\\$DC\sysvol\scripts\$FQDN\Sysmon\$BINARCH"
$GLBSYSMONCONFIG="\\$DC\sysvol\scripts\$FQDN\Sysmon\sysmonConfig.xml"
  
function installsysmon {
    if (!(test-path $SYSMONDIR)) {
        new-item -Type Directory -Path $SYSMONDIR}
    Copy-Item -path $GLBSYSMONBIN -destination $SYSMONDIR -Recurse
    Copy-Item -path $GLBSYSMONCONFIG -destination $SYSMONDIR -Recurse
    cd $SYSMONDIR
    & $SYSMONBIN -i $SYSMONCONFIG -accepteula -h md5,sha256 -n -l
    Set-Service $SERVBINARCH -StartupType Automatic
}
#upates config of sysmon
function updateconfig{
    Copy-Item -path $GLBSYSMONCONFIG -destination $SYSMONCONFIG -recurse
    cd $SYSMONDIR
    & $SYSMONBIN -c $SYSMONCONFIG
    Exit $LASTEXITCODE
}
# If service not found on start runs installsysmon func. Else it compares sysmonconfig hashes if different it does an update just updates config  
function startsysmon {
    start-service $SERVBINARCH
    If (($error[0]).categoryinfo.category -eq "ObjectNotFound" ) {
        installsysmon} 
    elseif ((Get-FileHash -algorithm sha256 -Path $GLBSYSMONCONFIG).hash -ne (Get-FileHash -algorithm sha256 -Path $SYSMONCONFIG).hash) {
        updateconfig}
}

# runs startsysmon function
startsysmon