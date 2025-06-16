. (Join-Path $PSScriptRoot "core/monitor-cpu.ps1")

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()
Write-Host "Listening on http://localhost:8080/"
Write-Host "==> Dashboard: http://localhost:8080/dashboard <=="

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $response.Headers.Add("Access-Control-Allow-Origin", "*")
        $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
        
        Write-Host "HTTP-Anfrage erhalten für: $($request.Url.AbsolutePath)"
        

        if ($request.Url.AbsolutePath -eq "/dashboard") {
            $htmlPath = Join-Path $PSScriptRoot "dashboard/dashboard.html"
            if (Test-Path $htmlPath) {
                $htmlContent = Get-Content $htmlPath -Raw
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlContent)
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $buffer.Length
                $response.StatusCode = 200
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            else {
                $response.StatusCode = 404
                Write-Host "HTML-Datei nicht gefunden"
            }
        }
        else {
            try {
                $systemData = Get-AllSystemData
                $json = $systemData | ConvertTo-Json -Depth 10
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                $response.ContentType = "application/json"
                $response.ContentLength64 = $buffer.Length
                $response.StatusCode = 200
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            catch {
                Write-Host "Fehler beim Abrufen der Systemdaten: $($_.Exception.Message)"
                $errObj = @{ error = $_.Exception.Message }
                $errorMsg = $errObj | ConvertTo-Json
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($errorMsg)
                $response.ContentType = "application/json"
                $response.ContentLength64 = $buffer.Length
                $response.StatusCode = 500
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
        }
        $response.OutputStream.Close()
    }
    catch {
        Write-Host "Fehler im HTTP-Listener: $($_.Exception.Message)"
    }
}