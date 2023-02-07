$global:DefaultVIServers | Disconnect-VIServer -Confirm:$false
$vCenter = Connect-VIServer


$clusters = get-cluster

# These are the cutoff dated for the pre and post mesurements
$maintenanceStart = Get-Date("2023-01-16")
$maintenanceEnd = Get-Date("2023-01-16")
$intervalSeconds = 120*60 # Depending on you statistics level you might need to set this to once pr day.


$days = 14
$limitPercent = 3
$cpuUsageLimit = 20
$readyLimit = (($intervalSeconds * 1000) / 100) * $limitPercent # ((intervalSeconds * 1000ms) / 100%) * 1%)
$samples = ($days * 24 * 60 * 60) / $intervalSeconds

$clusterStats = @()

$timespans = @()
$timespans += [PSCustomObject]@{
    Name = "new"
    Start = $maintenanceEnd.AddDays(+1)    
    End = $maintenanceEnd.AddDays($days+1)
}

$timespans += [PSCustomObject]@{
    Name = "old"
    Start = $maintenanceStart.AddDays(-($days+1))
    End = $maintenanceStart.AddDays(-1)
}


Foreach ($cluster in $clusters) {
    $clusterName = $cluster.name
    $VMs = $cluster | Get-VM | Sort-Object -Property Name

    $clusterStat = [PSCustomObject]@{
        Name = $clusterName
    }

    foreach($timespan in $timespans) {
        $relevantStats = @()
        $okVMs = @()
        $overloadedVMs = @()

        Write-Host "Checking Timespace: $($timespan.Start) - $($timespan.End)"
        Foreach ($vm in $VMs) {
            $VMName = $vm.Name
            Write-Host "Checking Cluster: $($clusterName) VM: $($VMName)" -NoNewline

            try {
                $readyStats = $vm | ForEach-Object { $_ | Get-Stat -Start $timespan.Start -Finish $timespan.End -Stat cpu.ready.summation -MaxSamples $samples -IntervalSecs $intervalSeconds -ErrorAction:Stop | Where-Object {$_.Value -ge $readyLimit}}
                $usageStats = $vm | ForEach-Object { $_ | Get-Stat -Start $timespan.Start -Finish $timespan.End -Stat cpu.usage.average -MaxSamples $samples -IntervalSecs $intervalSeconds  -ErrorAction:Stop}
            }
            catch {
                Write-Host " - Failed"
                continue
            }


            $overloaded = $false
            foreach ($stat in $readyStats) {
                $timeStamp = $stat.Timestamp
                $cpuUsageStat = $usageStats | Where-Object { $_.Timestamp -match $timeStamp -and $_.Entity.Name -match $VMName }

                if ($cpuUsageStat) {
                    $utilizationPercent = $cpuUsageStat.Value
                    if ($utilizationPercent -ge $cpuUsageLimit) {
                        $overloaded = $true
                        $cpuTimeStamp = $cpuUsageStat.Timestamp
                        #Write-Host "$($VMName) $($timeStamp) $($stat.Value) $($utilizationPercent)"
                        $relevantStats += [PSCustomObject]@{
                            Name = $stat.Entity.Name
                            ReadyPercent = [math]::Round((100 / ($intervalSeconds * 1000)) * $stat.Value, 1)
                            UsagePercent = $utilizationPercent
                        }
                    }
                }
            }
            if ($overloaded) {
                Write-Host " - Overloaded" -NoNewline
                $overloadedVMs += $vm
            } else {
                Write-Host " - OK" -NoNewline
                $okVMs += $vm
            }
            if ($usageStats.length -ne $samples) {
                Write-Host " (Samples: $($usageStats.length) Expected: $($samples))"
            } else {
                Write-Host ""
            }
        }
        $clusterStat | Add-Member -MemberType NoteProperty -Name "OK-$($timespan.Name)" -Value $okVMs
        $clusterStat | Add-Member -MemberType NoteProperty -Name "Overloaded-$($timespan.Name)" -Value $overloadedVMs
        $clusterStat | Add-Member -MemberType NoteProperty -Name "OkCount-$($timespan.Name)" -Value $okVMs.Length
        $clusterStat | Add-Member -MemberType NoteProperty -Name "OverloadedCount-$($timespan.Name)" -Value $overloadedVMs.Length
        $clusterStat | Add-Member -MemberType NoteProperty -Name "OverloadedPct-$($timespan.Name)" -Value ([math]::round(((100 / ($okVMs.Length + $overloadedVMs.Length) * $overloadedVMs.Length)), 1))
    }
    $clusterStats += $clusterStat
    $clusterStats | Select-Object Name, OverloadedCOunt-old, OverloadedCount-new, OverloadedPct-old, OverloadedPct-new | Ft -Auto
}

 $clusterStats
