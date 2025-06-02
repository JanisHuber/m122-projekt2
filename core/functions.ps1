function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "INFO" { Write-Host $logEntry -ForegroundColor Green }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "CRITICAL" { Write-Host $logEntry -ForegroundColor Magenta }
    }
    
    $logPath = Join-Path $PSScriptRoot "..\logs\monitoring-log.txt"
    Add-Content -Path $logPath -Value $logEntry
}

function Get-Configuration {
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\thresholds.json")
    )
    
    try {
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            Write-Log "Konfiguration erfolgreich geladen von: $ConfigPath"
            return $config
        }
        else {
            Write-Log "Konfigurationsdatei nicht gefunden: $ConfigPath" -Level "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Fehler beim Laden der Konfiguration: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Log "Verzeichnis erstellt: $Path"
    }
}

function Clear-OldLogs {
    param(
        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 7
    )
    
    $logPath = Join-Path $PSScriptRoot "..\logs"
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    
    try {
        Get-ChildItem -Path $logPath -Filter "*.txt" | 
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-Log "Alte Log-Datei gelöscht: $($_.Name)"
        }
    }
    catch {
        Write-Log "Fehler beim Bereinigen alter Logs: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Format-Bytes {
    param(
        [Parameter(Mandatory = $true)]
        [long]$Bytes
    )
    
    $sizes = @("B", "KB", "MB", "GB", "TB")
    $index = 0
    $value = $Bytes
    
    while ($value -ge 1024 -and $index -lt ($sizes.Length - 1)) {
        $value = $value / 1024
        $index++
    }
    
    return "{0:N2} {1}" -f $value, $sizes[$index]
}

function Test-Threshold {
    param(
        [Parameter(Mandatory = $true)]
        [double]$CurrentValue,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Thresholds
    )
    
    if ($CurrentValue -ge $Thresholds.critical) {
        return "CRITICAL"
    }
    elseif ($CurrentValue -ge $Thresholds.warning) {
        return "WARNING"
    }
    else {
        return "OK"
    }
}

function Initialize-Monitoring {
    Write-Log "=== Monitoring Dashboard wird initialisiert ===" -Level "INFO"
    
    $baseDir = Split-Path $PSScriptRoot -Parent
    Ensure-Directory (Join-Path $baseDir "logs")
    Ensure-Directory (Join-Path $baseDir "output")
    
    $config = Get-Configuration
    if ($null -eq $config) {
        Write-Log "Initialisierung fehlgeschlagen - Konfiguration konnte nicht geladen werden" -Level "CRITICAL"
        return $false
    }
    
    if ($config.monitoring.logRetentionDays) {
        Clear-OldLogs -RetentionDays $config.monitoring.logRetentionDays
    }
    
    Write-Log "Monitoring Dashboard erfolgreich initialisiert" -Level "INFO"
    return $true
} 