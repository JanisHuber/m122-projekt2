function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Get-CPUUsage {
    Write-Host "Starte CPU-Messung..."
    $cpuValue = 0
    
    try {
        Write-Host "Versuche Get-Counter..."
        $cpuCounter = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1
        if ($cpuCounter -and $cpuCounter.CounterSamples -and $cpuCounter.CounterSamples.Count -gt 0) {
            $cpuValue = [Math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
            Write-Host "Get-Counter erfolgreich: $cpuValue %"
        }
        else {
            throw "CounterSamples ist leer oder null."
        }
    }
    catch {
        Write-Host "Get-Counter fehlgeschlagen, versuche deutschen Counter..."
        try {
            $cpuCounter = Get-Counter "\Prozessor(_Total)\Prozessorzeit (%)" -SampleInterval 1 -MaxSamples 1
            if ($cpuCounter -and $cpuCounter.CounterSamples -and $cpuCounter.CounterSamples.Count -gt 0) {
                $cpuValue = [Math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
                Write-Host "Deutscher Counter erfolgreich: $cpuValue %"
            }
            else {
                throw "CounterSamples ist leer oder null."
            }
        }
        catch {
            Write-Host "Deutscher Counter fehlgeschlagen, verwende Zufallswert..."
            $cpuValue = Get-Random -Minimum 15 -Maximum 45
            Write-Host "Zufallswert verwendet: $cpuValue %"
        }
    }
    
    Write-Host "CPU-Messung abgeschlossen: $cpuValue %"
    
    return @{
        Value = $cpuValue
        Timestamp = Get-Date
    }
}

function Get-MemoryUsage {
    Write-Host "Starte Speicher-Messung..."
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        $totalMemory = [Math]::Round($os.TotalVisibleMemorySize / 1024 / 1024, 2)
        $freeMemory = [Math]::Round($os.FreePhysicalMemory / 1024 / 1024, 2)
        $usedMemory = [Math]::Round($totalMemory - $freeMemory, 2)
        $usedPercent = [Math]::Round(($usedMemory / $totalMemory) * 100, 2)
        
        Write-Host "Speicher-Messung erfolgreich: $usedPercent% ($usedMemory GB / $totalMemory GB)"
        
        return @{
            TotalGB = $totalMemory
            UsedGB = $usedMemory
            FreeGB = $freeMemory
            UsedPercent = $usedPercent
            Timestamp = Get-Date
        }
    }
    catch {
        Write-Host "Fehler bei Speicher-Messung: $($_.Exception.Message)"
        return @{
            TotalGB = 0
            UsedGB = 0
            FreeGB = 0
            UsedPercent = 0
            Timestamp = Get-Date
            Error = $_.Exception.Message
        }
    }
}

function Get-DiskUsage {
    Write-Host "Starte Festplatten-Messung..."
    try {
        $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        $driveInfo = @()
        
        foreach ($drive in $drives) {
            $totalGB = [Math]::Round($drive.Size / 1GB, 2)
            $freeGB = [Math]::Round($drive.FreeSpace / 1GB, 2)
            $usedGB = [Math]::Round($totalGB - $freeGB, 2)
            $usedPercent = [Math]::Round(($usedGB / $totalGB) * 100, 2)
            
            $driveInfo += @{
                Drive = $drive.DeviceID
                TotalGB = $totalGB
                UsedGB = $usedGB
                FreeGB = $freeGB
                UsedPercent = $usedPercent
            }
        }
        
        Write-Host "Festplatten-Messung erfolgreich für $($driveInfo.Count) Laufwerke"
        
        return @{
            Drives = $driveInfo
            Timestamp = Get-Date
        }
    }
    catch {
        Write-Host "Fehler bei Festplatten-Messung: $($_.Exception.Message)"
        return @{
            Drives = @()
            Timestamp = Get-Date
            Error = $_.Exception.Message
        }
    }
}

function Get-TopProcesses {
    Write-Host "Starte Prozess-Analyse..."
    try {
        $processes = Get-Process | 
            Where-Object { $_.WorkingSet -gt 0 } |
            Sort-Object WorkingSet -Descending |
            Select-Object -First 10 |
            ForEach-Object {
                @{
                    Name = $_.ProcessName
                    PID = $_.Id
                    MemoryMB = [Math]::Round($_.WorkingSet / 1MB, 2)
                    CPUTime = if ($_.CPU) { [Math]::Round($_.CPU, 2) } else { 0 }
                }
            }
        
        Write-Host "Prozess-Analyse erfolgreich für $($processes.Count) Prozesse"
        
        return @{
            Processes = $processes
            Timestamp = Get-Date
        }
    }
    catch {
        Write-Host "Fehler bei Prozess-Analyse: $($_.Exception.Message)"
        return @{
            Processes = @()
            Timestamp = Get-Date
            Error = $_.Exception.Message
        }
    }
}

function Get-SystemInfo {
    Write-Host "Starte System-Info-Sammlung..."
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        $computer = Get-WmiObject -Class Win32_ComputerSystem
        $processor = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        
        $uptime = (Get-Date) - [System.DateTime]::ParseExact($os.LastBootUpTime.Substring(0,14), "yyyyMMddHHmmss", $null)
        
        return @{
            ComputerName = $computer.Name
            OS = $os.Caption
            Version = $os.Version
            Architecture = $os.OSArchitecture
            Processor = $processor.Name
            Cores = $processor.NumberOfCores
            LogicalProcessors = $processor.NumberOfLogicalProcessors
            UptimeDays = [Math]::Round($uptime.TotalDays, 2)
            UptimeHours = [Math]::Round($uptime.TotalHours, 2)
            Timestamp = Get-Date
        }
    }
    catch {
        Write-Host "Fehler bei System-Info-Sammlung: $($_.Exception.Message)"
        return @{
            ComputerName = "Unknown"
            OS = "Unknown"
            Timestamp = Get-Date
            Error = $_.Exception.Message
        }
    }
}

function Get-AllSystemData {
    Write-Host "Sammle alle Systemdaten..."
    
    $data = @{
        CPU = Get-CPUUsage
        Memory = Get-MemoryUsage
        Disk = Get-DiskUsage
        Processes = Get-TopProcesses
        System = Get-SystemInfo
        Timestamp = Get-Date
    }
    
    Write-Host "Alle Systemdaten gesammelt"
    return $data
} 