# =============================================================================
# Monitoring Dashboard - Zentrale Steuerung
# =============================================================================

param(
    [Parameter(Mandatory = $false)]
    [switch]$Continuous,
    
    [Parameter(Mandatory = $false)]
    [int]$IntervalMinutes = 5,
    
    [Parameter(Mandatory = $false)]
    [switch]$NoEmail,
    
    [Parameter(Mandatory = $false)]
    [switch]$OpenDashboard
)

# Importiere alle Module
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $scriptPath "core\functions.ps1")
. (Join-Path $scriptPath "core\monitor-cpu.ps1")
. (Join-Path $scriptPath "dashboard\generate-html.ps1")

# Hauptfunktion
function Start-MonitoringDashboard {
    param(
        [Parameter(Mandatory = $false)]
        [bool]$ContinuousMode = $false,
        
        [Parameter(Mandatory = $false)]
        [int]$Interval = 5,
        
        [Parameter(Mandatory = $false)]
        [bool]$SendEmails = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$OpenBrowser = $false
    )
    
    try {
        # Banner anzeigen
        Show-Banner
        
        # Initialisiere Monitoring-System
        if (-not (Initialize-Monitoring)) {
            Write-Log "Monitoring konnte nicht initialisiert werden - Beende Programm" -Level "CRITICAL"
            return $false
        }
        
        # Lade Konfiguration
        $config = Get-Configuration
        if ($null -eq $config) {
            Write-Log "Konfiguration konnte nicht geladen werden - Beende Programm" -Level "CRITICAL"
            return $false
        }
        
        Write-Log "=== Monitoring Dashboard gestartet ===" -Level "INFO"
        Write-Log "Kontinuierlicher Modus: $ContinuousMode" -Level "INFO"
        Write-Log "Intervall: $Interval Minuten" -Level "INFO"
        
        do {
            # Führe Monitoring-Zyklus aus
            $success = Invoke-MonitoringCycle -Config $config -SendEmails $SendEmails
            
            if ($success -and $OpenBrowser) {
                # Öffne Dashboard im Browser (nur beim ersten Mal)
                $dashboardPath = Join-Path $scriptPath "output\dashboard.html"
                if (Test-Path $dashboardPath) {
                    Write-Log "Öffne Dashboard im Browser: $dashboardPath" -Level "INFO"
                    Start-Process $dashboardPath
                    $OpenBrowser = $false # Nur einmal öffnen
                }
            }
            
            if ($ContinuousMode) {
                Write-Log "Warte $Interval Minuten bis zum nächsten Monitoring-Zyklus..." -Level "INFO"
                Start-Sleep -Seconds ($Interval * 60)
            }
            
        } while ($ContinuousMode)
        
        Write-Log "=== Monitoring Dashboard beendet ===" -Level "INFO"
        return $true
        
    }
    catch {
        Write-Log "Kritischer Fehler im Monitoring Dashboard: $($_.Exception.Message)" -Level "CRITICAL"
        return $false
    }
}

# Funktion für einen Monitoring-Zyklus
function Invoke-MonitoringCycle {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $false)]
        [bool]$SendEmails = $true
    )
    
    try {
        Write-Log "=== Starte Monitoring-Zyklus ===" -Level "INFO"
        $cycleStartTime = Get-Date
        
        # Sammle alle Monitoring-Ergebnisse
        $monitoringResults = @()
        
        # CPU-Monitoring
        Write-Log "Führe CPU-Monitoring durch..." -Level "INFO"
        $cpuResult = Monitor-CPU -Config $Config
        if ($null -ne $cpuResult) {
            $monitoringResults += $cpuResult
        }
        else {
            Write-Log "CPU-Monitoring fehlgeschlagen" -Level "ERROR"
        }
        
        # Generiere HTML-Dashboard
        if ($monitoringResults.Count -gt 0) {
            Write-Log "Generiere HTML-Dashboard..." -Level "INFO"
            $dashboardPath = Generate-HTMLDashboard -MonitoringResults $monitoringResults
            
            if ($null -ne $dashboardPath) {
                Write-Log "Dashboard erfolgreich erstellt: $dashboardPath" -Level "INFO"
            }
            else {
                Write-Log "Dashboard-Generierung fehlgeschlagen" -Level "ERROR"
            }
        }
        else {
            Write-Log "Keine Monitoring-Ergebnisse verfügbar - Dashboard wird nicht generiert" -Level "WARNING"
        }
        
        # Zeige Zusammenfassung
        Show-CycleSummary -MonitoringResults $monitoringResults -StartTime $cycleStartTime
        
        return $true
        
    }
    catch {
        Write-Log "Fehler im Monitoring-Zyklus: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Funktion zum Anzeigen des Banners
function Show-Banner {
    $banner = @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                      MONITORING DASHBOARD v1.0                              ║
║                                                                              ║
║                          PowerShell System Monitor                          ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@
    
    Write-Host $banner -ForegroundColor Cyan
    Write-Host "System: $env:COMPUTERNAME | Benutzer: $env:USERNAME | Zeit: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
}

# Funktion zum Anzeigen der Zyklus-Zusammenfassung
function Show-CycleSummary {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$MonitoringResults,
        
        [Parameter(Mandatory = $true)]
        [datetime]$StartTime
    )
    
    $duration = (Get-Date) - $StartTime
    $durationText = "{0:N1} Sekunden" -f $duration.TotalSeconds
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                            ZYKLUS ZUSAMMENFASSUNG                           ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Ausführungszeit: $durationText" -ForegroundColor Gray
    Write-Host "Überwachte Metriken: $($MonitoringResults.Count)" -ForegroundColor Gray
    Write-Host ""
    
    if ($MonitoringResults.Count -gt 0) {
        # Zeige Status-Übersicht
        $statusCounts = @{}
        $MonitoringResults | ForEach-Object {
            if ($statusCounts.ContainsKey($_.Status)) {
                $statusCounts[$_.Status]++
            }
            else {
                $statusCounts[$_.Status] = 1
            }
        }
        
        Write-Host "Status-Übersicht:" -ForegroundColor White
        foreach ($status in $statusCounts.Keys | Sort-Object) {
            $icon = switch ($status) {
                "OK" { "[OK]" }
                "WARNING" { "[WARN]" }
                "CRITICAL" { "[CRIT]" }
                default { "[INFO]" }
            }
            
            $color = switch ($status) {
                "OK" { "Green" }
                "WARNING" { "Yellow" }
                "CRITICAL" { "Red" }
                default { "Gray" }
            }
            
            Write-Host "   $icon $status : $($statusCounts[$status])" -ForegroundColor $color
        }
        
        Write-Host ""
        
        # Zeige Details für jede Metrik
        Write-Host "Metrik-Details:" -ForegroundColor White
        foreach ($result in $MonitoringResults) {
            $statusIcon = switch ($result.Status) {
                "OK" { "[OK]" }
                "WARNING" { "[WARN]" }
                "CRITICAL" { "[CRIT]" }
                default { "[INFO]" }
            }
            
            $color = switch ($result.Status) {
                "OK" { "Green" }
                "WARNING" { "Yellow" }
                "CRITICAL" { "Red" }
                default { "Gray" }
            }
            
            Write-Host "   $statusIcon $($result.Type): $($result.Value) $($result.Unit) ($($result.Status))" -ForegroundColor $color
        }
    }
    
    Write-Host ""
    Write-Host "Dashboard verfügbar unter: $(Join-Path $scriptPath 'output\dashboard.html')" -ForegroundColor Cyan
    Write-Host ""
}

# Funktion zum Anzeigen der Hilfe
function Show-Help {
    Write-Host ""
    Write-Host "MONITORING DASHBOARD - Hilfe" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "VERWENDUNG:" -ForegroundColor White
    Write-Host "  .\run.ps1 [Parameter]" -ForegroundColor Gray
    Write-Host ""
    Write-Host "PARAMETER:" -ForegroundColor White
    Write-Host "  -Continuous          Kontinuierlicher Modus (läuft dauerhaft)" -ForegroundColor Gray
    Write-Host "  -IntervalMinutes     Intervall zwischen Checks in Minuten (Standard: 5)" -ForegroundColor Gray
    Write-Host "  -OpenDashboard       Öffnet das Dashboard automatisch im Browser" -ForegroundColor Gray
    Write-Host ""
    Write-Host "BEISPIELE:" -ForegroundColor White
    Write-Host "  .\run.ps1                                    # Einmaliger Check" -ForegroundColor Gray
    Write-Host "  .\run.ps1 -Continuous                       # Kontinuierlicher Modus" -ForegroundColor Gray
    Write-Host "  .\run.ps1 -Continuous -IntervalMinutes 10   # Alle 10 Minuten" -ForegroundColor Gray
    Write-Host "  .\run.ps1 -OpenDashboard                    # Mit Browser" -ForegroundColor Gray
    Write-Host ""
    Write-Host "KONFIGURATION:" -ForegroundColor White
    Write-Host "  Bearbeiten Sie config\thresholds.json für Schwellenwerte." -ForegroundColor Gray
    Write-Host ""
}

# Hauptprogramm
if ($args -contains "-help" -or $args -contains "--help" -or $args -contains "/?") {
    Show-Help
    exit 0
}

# Starte Monitoring Dashboard
$success = Start-MonitoringDashboard -ContinuousMode $Continuous -Interval $IntervalMinutes -OpenBrowser $OpenDashboard

if (-not $success) {
    Write-Host ""
    Write-Host "Monitoring Dashboard wurde mit Fehlern beendet!" -ForegroundColor Red
    Write-Host "Überprüfen Sie die Log-Datei für Details: logs\monitoring-log.txt" -ForegroundColor Yellow
    exit 1
}
else {
    Write-Host ""
    Write-Host "Monitoring Dashboard erfolgreich ausgeführt!" -ForegroundColor Green
    exit 0
} 