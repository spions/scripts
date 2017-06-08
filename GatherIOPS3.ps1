$server = ""
$username = ""
$password = ""
$numsamples = -120
#$aVm=@("srv-serv1","srv-serv2")  # or 'all'
$aVm=@("all")  # or 'all'

#powershell -ExecutionPolicy ByPass -File GatherIOPS3.ps1
#https://communities.vmware.com/thread/447275

if ($server -eq $null) {
    $server = read-host -prompt "Please enter vmware host"
}

if ($username -eq $null) {
    $username = read-host -prompt "Please enter local user account for host access"
}


if ($password -eq $null) {
    $password = read-host -prompt "Please enter password for host account" -assecurestring
} else {
    $password = $password | ConvertTo-SecureString -AsPlainText -Force
}

do {    
    $date= read-host "Please enter statistic finish date & time ('25/12/2012 09:00', '25 oct 2012 9:00', or say 'now')"

    if ($date -eq "now" ) {$date = Get-Date}

    $date = $date -as [datetime]
    if (!$date) { "Not A valid date and time"}

} while ($date -isnot [datetime])


$credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$password

# add VMware PS snapin
if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
    Add-PSSnapin VMware.VimAutomation.Core
}

# connect vCenter server session
connect-viserver -server $server -credential $credentials -NotDefault -WarningAction SilentlyContinue | Out-Null

$metrics = "disk.numberwrite.summation","disk.numberread.summation"
$finish = $date
$start = $finish.AddMinutes($numsamples)
$report = @()


if ($aVm -eq 'all') {
    $vms = Get-VM -server $server | where {$_.PowerState -eq "PoweredOn"}  | Sort-Object -Unique
} else {
    $vms = Get-VM -server $server | where {$_.PowerState -eq "PoweredOn" -and ($aVm -like $_.Name)}  | Sort-Object -Unique
}

$stats = Get-Stat -Stat $metrics -Entity $vms -Start $start -Finish $finish
$interval = $stats[0].IntervalSecs

$lunTab = @{}

$sizeTab=$VMs | Get-HardDisk | Select-Object -Property Parent,Name,StorageFormat,CapacityGB, @{Name="Datastore";Expression={$_.FileName.Split(']')[0].TrimStart('[')}}  | 
Group-Object -Property Datastore,Parent | %{
        New-Object psobject -Property @{
        Item = $_.Name
        Sum = ($_.Group  | Measure-Object -Property CapacityGB -sum).Sum
        }
    }


foreach($ds in (Get-Datastore -VM $vms | where {$_.Type -eq "VMFS"})){
  #Sort-Object -Property Filename
  $ds.ExtensionData.Info.Vmfs.Extent | %{
    $lunTab[$_.DiskName] = $ds.Name
  }
}



$report = $stats | Group-Object -Property {$_.Entity.Name},Instance | %{
  
  $readStat = $_.Group |
    where{$_.MetricId -eq "disk.numberread.summation"} |
    Measure-Object -Property Value -Average -Maximum
  
  $writeStat = $_.Group |
    where{$_.MetricId -eq "disk.numberwrite.summation"} |
    Measure-Object -Property Value -Average -Maximum 
  
  New-Object PSObject -Property @{
    VM = $_.Values[0]
    Start = $start
    Finish = $finish
    Disk = $_.Values[1]
    IOPSWriteMax = [math]::Round($writeStat.Maximum/$interval,0)
    IOPSWriteAvg = [math]::Round($writeStat.Average/$interval,0)
    IOPSReadMax = [math]::Round($readStat.Maximum/$interval,0)
    IOPSReadAvg = [math]::Round($readStat.Average/$interval,0)
    Datastore = $lunTab[$_.Values[1]]
    Size = [math]::Round(($sizeTab -match $lunTab[$_.Values[1]]+", "+$_.Values[0] | Select-Object -ExpandProperty Sum))
  }
}

$report | Select VM,Start,Finish,Disk,Datastore,IOPSWriteAvg,IOPSWriteMax,IOPSReadAvg,IOPSReadMax,Size | Format-Table
$report | Export-CSV IOPSReport3.csv -NoType
