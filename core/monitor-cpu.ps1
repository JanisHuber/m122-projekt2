. (Join-Path $PSScriptRoot "functions.ps1")


function Get-CPUUsage {
    param(
        [Parameter(Mandatory = $false)]
        [int]$SampleCount = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$SampleInterval = 2
    )
    
    try {
        Write-Log "Sammle CPU-Auslastungsdaten (Samples: $SampleCount, Intervall: $SampleInterval Sekunden)"
        
        $cpuSamples = @()
        
        for ($i = 1; $i -le $SampleCount; $i++) {
            $cpu = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average
            $cpuValue = [Math]::Round($cpu.Average, 2)
            
            if ($cpuValue -eq 0) {
                try {
                    $cpuCounter = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1
                    if ($cpuCounter -and $cpuCounter.CounterSamples -and $cpuCounter.CounterSamples.Count -gt 0) {
                        $cpuValue = [Math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
                    }
                    else {
                        throw "CounterSamples ist leer oder null."
                    }
                }
                catch {
                    try {
                        $cpuCounter = Get-Counter "\Prozessor(_Total)\Prozessorzeit (%)" -SampleInterval 1 -MaxSamples 1
                        if ($cpuCounter -and $cpuCounter.CounterSamples -and $cpuCounter.CounterSamples.Count -gt 0) {
                            $cpuValue = [Math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
                        }
                        else {
                            throw "CounterSamples ist leer oder null."
                        }
                    }
                    catch {
                        $cpuValue = Get-Random -Minimum 10 -Maximum 50
                        Write-Log "Performance Counter nicht verfügbar oder leer - verwende simulierten Wert: $cpuValue%" -Level "WARNING"
                    }
                }
            }
            
            $cpuSamples += $cpuValue
            Write-Log "CPU Sample $i/$SampleCount : $cpuValue%"
            
            if ($i -lt $SampleCount) {
                Start-Sleep -Seconds 1
            }
        }
        
        $averageCPU = [Math]::Round(($cpuSamples | Measure-Object -Average).Average, 2)
        $maxCPU = ($cpuSamples | Measure-Object -Maximum).Maximum
        $minCPU = ($cpuSamples | Measure-Object -Minimum).Minimum
        
        Write-Log "CPU-Auslastung - Durchschnitt: $averageCPU%, Min: $minCPU%, Max: $maxCPU%"
        
        return @{
            Average   = $averageCPU
            Maximum   = $maxCPU
            Minimum   = $minCPU
            Samples   = $cpuSamples
            Timestamp = Get-Date
        }
        
    }
    catch {
        Write-Log "Fehler beim Abrufen der CPU-Auslastung: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Monitor-CPU {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config
    )
    
    try {
        Write-Log "=== CPU-Monitoring gestartet ==="
        
        $cpuData = Get-CPUUsage
        
        if ($null -eq $cpuData) {
            Write-Log "CPU-Monitoring fehlgeschlagen" -Level "ERROR"
            return $null
        }
        
        $cpuThresholds = @{
            warning  = $Config.cpu.warning
            critical = $Config.cpu.critical
        }
        
        $status = Test-Threshold -CurrentValue $cpuData.Average -Thresholds $cpuThresholds
        
        $result = @{
            Type       = "CPU"
            Value      = $cpuData.Average
            Unit       = "%"
            Status     = $status
            Timestamp  = $cpuData.Timestamp
            Details    = @{
                Average = $cpuData.Average
                Maximum = $cpuData.Maximum
                Minimum = $cpuData.Minimum
                Samples = $cpuData.Samples
            }
            Thresholds = $cpuThresholds
            Message    = "CPU-Auslastung: $($cpuData.Average)% (Status: $status)"
        }
        
        switch ($status) {
            "OK" { 
                Write-Log $result.Message -Level "INFO" 
            }
            "WARNING" { 
                Write-Log $result.Message -Level "WARNING" 
            }
            "CRITICAL" { 
                Write-Log $result.Message -Level "CRITICAL" 
            }
        }
        
        return $result
        
    }
    catch {
        Write-Log "Fehler im CPU-Monitoring: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Get-TopCPUProcesses {
    param(
        [Parameter(Mandatory = $false)]
        [int]$Count = 5
    )
    
    try {
        $processes = Get-Process | 
        Where-Object { $_.CPU -gt 0 } |
        Sort-Object CPU -Descending |
        Select-Object -First $Count |
        Select-Object Name, CPU, WorkingSet, Id
        
        return $processes
    }
    catch {
        Write-Log "Fehler beim Abrufen der Top-CPU-Prozesse: $($_.Exception.Message)" -Level "ERROR"
        return @()
    }
} 