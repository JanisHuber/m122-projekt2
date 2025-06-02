$listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:8080/")
    $listener.Start()
    Write-Host "Listening on http://localhost:8080/"

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response

        $data = @{ cpu = 42; uptime = "1 Tag" }
        $json = $data | ConvertTo-Json

        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
        $response.ContentType = "application/json"
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.OutputStream.Close()
    }