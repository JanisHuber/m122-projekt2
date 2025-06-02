. (Join-Path $PSScriptRoot "..\core\functions.ps1")

function Generate-HTMLDashboard {
    param(
        [Parameter(Mandatory = $true)]
        [array]$MonitoringResults,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = (Join-Path $PSScriptRoot "..\output\dashboard.html"),
        
        [Parameter(Mandatory = $false)]
        [object]$SystemInfo = $null
    )
    
    try {
        Write-Log "Generiere HTML-Dashboard mit $($MonitoringResults.Count) Monitoring-Ergebnissen"
        
        if ($null -eq $SystemInfo) {
            $SystemInfo = Get-SystemInfo
        }
        
        $html = Build-DashboardHTML -MonitoringResults $MonitoringResults -SystemInfo $SystemInfo
        
        $html | Set-Content -Path $OutputPath -Encoding UTF8
        
        Write-Log "HTML-Dashboard erfolgreich erstellt: $OutputPath" -Level "INFO"
        return $OutputPath
        
    }
    catch {
        Write-Log "Fehler beim Generieren des HTML-Dashboards: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Build-DashboardHTML {
    param(
        [Parameter(Mandatory = $true)]
        [array]$MonitoringResults,
        
        [Parameter(Mandatory = $true)]
        [object]$SystemInfo
    )
    
    $timestamp = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
    
    $overallStatus = Get-OverallStatus -MonitoringResults $MonitoringResults
    $statusColor = Get-StatusColor -Status $overallStatus
    $statusIcon = Get-StatusIcon -Status $overallStatus
    
    $html = @"
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Monitoring Dashboard - $($SystemInfo.ComputerName)</title>
    <meta http-equiv="refresh" content="30">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            backdrop-filter: blur(10px);
            text-align: center;
        }
        
        .header h1 {
            color: #2c3e50;
            font-size: 2.5em;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 15px;
        }
        
        .header .subtitle {
            color: #7f8c8d;
            font-size: 1.2em;
            margin-bottom: 20px;
        }
        
        .status-overview {
            display: inline-block;
            padding: 15px 30px;
            border-radius: 25px;
            color: white;
            font-weight: bold;
            font-size: 1.1em;
            background-color: $statusColor;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
        }
        
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 25px;
            margin-bottom: 30px;
        }
        
        .metric-card {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            backdrop-filter: blur(10px);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .metric-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 20px;
        }
        
        .metric-title {
            font-size: 1.3em;
            font-weight: bold;
            color: #2c3e50;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .metric-status {
            padding: 8px 16px;
            border-radius: 20px;
            color: white;
            font-weight: bold;
            font-size: 0.9em;
        }
        
        .status-ok { background-color: #27ae60; }
        .status-warning { background-color: #f39c12; }
        .status-critical { background-color: #e74c3c; }
        
        .metric-value {
            font-size: 3em;
            font-weight: bold;
            color: #2c3e50;
            margin-bottom: 10px;
        }
        
        .metric-unit {
            font-size: 0.4em;
            color: #7f8c8d;
            margin-left: 5px;
        }
        
        .metric-details {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 15px;
            margin-top: 15px;
        }
        
        .detail-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
            font-size: 0.9em;
        }
        
        .detail-row:last-child {
            margin-bottom: 0;
        }
        
        .detail-label {
            color: #7f8c8d;
            font-weight: 500;
        }
        
        .detail-value {
            color: #2c3e50;
            font-weight: bold;
        }
        
        .progress-bar {
            width: 100%;
            height: 8px;
            background-color: #ecf0f1;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 10px;
        }
        
        .progress-fill {
            height: 100%;
            border-radius: 4px;
            transition: width 0.3s ease;
        }
        
        .system-info {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            backdrop-filter: blur(10px);
            margin-bottom: 30px;
        }
        
        .system-info h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
        }
        
        .footer {
            text-align: center;
            color: rgba(255, 255, 255, 0.8);
            margin-top: 30px;
            font-size: 0.9em;
        }
        
        .refresh-info {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            padding: 15px;
            margin-top: 15px;
            color: rgba(255, 255, 255, 0.9);
        }
        
        @media (max-width: 768px) {
            .metrics-grid {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 2em;
                flex-direction: column;
                gap: 10px;
            }
            
            .metric-value {
                font-size: 2.5em;
            }
        }
        
        .grouped-info {
            margin-bottom: 18px;
            font-size: 1.1em;
            display: flex;
            gap: 8px;
        }
        
        .system-info-row {
            display: flex;
            flex-direction: row;
            gap: 48px;
            align-items: center;
            margin-bottom: 18px;
        }
        .info-group {
            display: flex;
            flex-direction: row;
            gap: 6px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>
                <span>[PC]</span>
                <span>Monitoring Dashboard</span>
            </h1>
            <div class="subtitle">System: $($SystemInfo.ComputerName) | Letzte Aktualisierung: $timestamp</div>
            <div class="status-overview">
                $statusIcon Gesamt-Status: $overallStatus
            </div>
        </div>
        
        <div class="metrics-grid">
"@

    foreach ($result in $MonitoringResults) {
        $html += Build-MetricCard -MonitoringResult $result
    }
    
    $html += @"
        </div>
        
        <div class="system-info">
            <h2>[SYS] System-Informationen</h2>
            <div class="system-info-row">
                <span class="info-group"><span class="detail-label">[PC] Computer:</span> <span class="detail-value">$($SystemInfo.ComputerName)</span></span>
                <span class="info-group"><span class="detail-label">[USER] Benutzer:</span> <span class="detail-value">$($SystemInfo.Username)</span></span>
                <span class="info-group"><span class="detail-label">[UP] Uptime:</span> <span class="detail-value">$($SystemInfo.Uptime)</span></span>
            </div>
        </div>
        
        <div class="footer">
            <div class="refresh-info">
                [REFRESH] Automatische Aktualisierung alle 30 Sekunden | <span id="next-refresh"></span>
            </div>
            <p style="margin-top: 15px;">
                Monitoring Dashboard | Generiert am $(Get-Date -Format "dd.MM.yyyy HH:mm:ss")
            </p>
        </div>
    </div>
    
    <script>
        let refreshCountdown = 30; 
        function pad(num) { return num.toString().padStart(2, '0'); }
        function updateCountdown() {
            const now = new Date();
            const nextRefresh = new Date(now.getTime() + refreshCountdown * 1000);
            const nextTime = pad(nextRefresh.getHours()) + ':' + pad(nextRefresh.getMinutes()) + ':' + pad(nextRefresh.getSeconds());
            document.title = '[' + Math.floor(refreshCountdown / 60) + ':' + pad(refreshCountdown % 60) + '] Monitoring Dashboard';
            document.getElementById('next-refresh').textContent =
                'Nächste Aktualisierung in ' + refreshCountdown + 's (' + nextTime + ')';
            if (refreshCountdown > 0) {
                refreshCountdown--;
                setTimeout(updateCountdown, 1000);
            }
        }
        updateCountdown();
    </script>
</body>
</html>
"@

    return $html
}

function Build-MetricCard {
    param(
        [Parameter(Mandatory = $true)]
        [object]$MonitoringResult
    )
    
    $statusClass = "status-" + $MonitoringResult.Status.ToLower()
    $statusIcon = Get-StatusIcon -Status $MonitoringResult.Status
    $progressColor = Get-StatusColor -Status $MonitoringResult.Status
    
    $maxThreshold = [Math]::Max($MonitoringResult.Thresholds.warning, $MonitoringResult.Thresholds.critical)
    $progressPercent = [Math]::Min(($MonitoringResult.Value / $maxThreshold) * 100, 100)
    
    $typeIcon = switch ($MonitoringResult.Type) {
        "CPU" { "[CPU]" }
        "Memory" { "[MEM]" }
        "Disk" { "[DISK]" }
        "Network" { "[NET]" }
        default { "[METRIC]" }
    }
    
    $card = @"
            <div class="metric-card">
                <div class="metric-header">
                    <div class="metric-title">
                        <span>$typeIcon</span>
                        <span>$($MonitoringResult.Type)</span>
                    </div>
                    <div class="metric-status $statusClass">
                        $statusIcon $($MonitoringResult.Status)
                    </div>
                </div>
                
                <div class="metric-value">
                    $($MonitoringResult.Value)<span class="metric-unit">$($MonitoringResult.Unit)</span>
                </div>
                
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $progressPercent%; background-color: $progressColor;"></div>
                </div>
                
                <div class="metric-details">
                    <div class="detail-row">
                        <span class="detail-label">Warning Schwelle:</span>
                        <span class="detail-value">$($MonitoringResult.Thresholds.warning) $($MonitoringResult.Unit)</span>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">Critical Schwelle:</span>
                        <span class="detail-value">$($MonitoringResult.Thresholds.critical) $($MonitoringResult.Unit)</span>
                    </div>
"@

    if ($MonitoringResult.Details) {
        if ($MonitoringResult.Details.Maximum) {
            $card += @"
                    <div class="detail-row">
                        <span class="detail-label">Maximum:</span>
                        <span class="detail-value">$($MonitoringResult.Details.Maximum) $($MonitoringResult.Unit)</span>
                    </div>
"@
        }
        if ($MonitoringResult.Details.Minimum) {
            $card += @"
                    <div class="detail-row">
                        <span class="detail-label">Minimum:</span>
                        <span class="detail-value">$($MonitoringResult.Details.Minimum) $($MonitoringResult.Unit)</span>
                    </div>
"@
        }
    }
    
    $card += @"
                    <div class="detail-row">
                        <span class="detail-label">Letztes Update:</span>
                        <span class="detail-value">$($MonitoringResult.Timestamp.ToString("HH:mm:ss"))</span>
                    </div>
                </div>
            </div>
"@

    return $card
}

function Build-SystemInfoGrid {
    param(
        [Parameter(Mandatory = $true)]
        [object]$SystemInfo
    )
    
    $grid = @"
                <div class="system-info-row">
                    <span class="info-group"><span class="detail-label">[PC] Computer:</span> <span class="detail-value">$($SystemInfo.ComputerName)</span></span>
                    <span class="info-group"><span class="detail-label">[USER] Benutzer:</span> <span class="detail-value">$($SystemInfo.Username)</span></span>
                    <span class="info-group"><span class="detail-label">[UP] Uptime:</span> <span class="detail-value">$($SystemInfo.Uptime)</span></span>
                </div>
"@

    return $grid
}

function Get-OverallStatus {
    param([array]$MonitoringResults)
    
    if ($MonitoringResults | Where-Object { $_.Status -eq "CRITICAL" }) {
        return "CRITICAL"
    }
    elseif ($MonitoringResults | Where-Object { $_.Status -eq "WARNING" }) {
        return "WARNING"
    }
    else {
        return "OK"
    }
}

function Get-StatusColor {
    param([string]$Status)
    
    switch ($Status) {
        "OK" { return "#27ae60" }
        "WARNING" { return "#f39c12" }
        "CRITICAL" { return "#e74c3c" }
        default { return "#95a5a6" }
    }
}

function Get-StatusIcon {
    param([string]$Status)
    
    switch ($Status) {
        "OK" { return "[OK]" }
        "WARNING" { return "[WARN]" }
        "CRITICAL" { return "[CRIT]" }
        default { return "[INFO]" }
    }
}

function Get-SystemInfo {
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        $uptime = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)
        
        return @{
            ComputerName = $env:COMPUTERNAME
            Username     = $env:USERNAME
            Uptime       = "$($uptime.Days) Tage, $($uptime.Hours) Stunden, $($uptime.Minutes) Minuten"
        }
    }
    catch {
        Write-Log "Fehler beim Abrufen der System-Informationen: $($_.Exception.Message)" -Level "ERROR"
        return @{
            ComputerName = $env:COMPUTERNAME
            Username     = $env:USERNAME
            Uptime       = "Unbekannt"
        }
    }
} 