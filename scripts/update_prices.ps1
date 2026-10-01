# PowerShell Price & FX Updater
$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir
$pricesFile = Join-Path $repoDir "data\prices.json"

Write-Host "Updating: $pricesFile"

$tickers = @(
    "AAPL", "AMD", "AMZN", "BRK-B", "COIN", "GOOGL", "INTC", 
    "JEPI", "JEPQ", "META", "MSFT", "NFLX", "NVDA", "PLTR", 
    "QQQ", "QQQM", "SCHD", "SMH", "SOXX", "SPY", "TSLA", 
    "VOO", "VTI", "VXUS"
)

# Fetch USDTHB
$usdThb = 33.60
try {
    $fxRes = Invoke-RestMethod -Uri "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json" -TimeoutSec 5
    if ($fxRes -and $fxRes.usd -and $fxRes.usd.thb) {
        $usdThb = [math]::Round([double]$fxRes.usd.thb, 4)
    }
} catch {
    Write-Host "FX error: $($_.Exception.Message)"
}
Write-Host "USD/THB: $usdThb"

$indicesConfig = @{
    "^DJI" = "Dow Jones"
    "^GSPC" = "S&P 500"
    "^IXIC" = "Nasdaq"
}

$indicesData = [ordered]@{}
$headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }

foreach ($sym in @("^DJI", "^GSPC", "^IXIC")) {
    $name = $indicesConfig[$sym]
    $idxSuccess = $false
    foreach ($u in @("https://query2.finance.yahoo.com/v8/finance/chart/$([System.Uri]::EscapeDataString($sym))?interval=1d", "https://query1.finance.yahoo.com/v8/finance/chart/$([System.Uri]::EscapeDataString($sym))")) {
        try {
            $res = Invoke-RestMethod -Uri $u -Headers $headers -TimeoutSec 8
            $m = $res.chart.result[0].meta
            $price = [double]($m.regularMarketPrice)
            $prev = [double]($m.chartPreviousClose)
            if (-not $prev -or $prev -le 0) { $prev = [double]($m.previousClose) }
            if (-not $prev -or $prev -le 0) { $prev = $price }
            
            $diff = [math]::Round($price - $prev, 2)
            $pct = if ($prev -gt 0) { [math]::Round(($diff / $prev) * 100, 2) } else { 0.0 }
            
            $indicesData[$sym] = [ordered]@{
                name = $name
                price = [math]::Round($price, 2)
                prevClose = [math]::Round($prev, 2)
                change = $diff
                changePct = $pct
            }
            Write-Host "  Index OK: $name = $price ($pct %)"
            $idxSuccess = $true
            break
        } catch {}
    }
    if (-not $idxSuccess) {
        Write-Host "  Index FAIL: $name"
    }
}

$pricesData = [ordered]@{}
foreach ($tk in $tickers) {
    $tkSuccess = $false
    foreach ($u in @("https://query2.finance.yahoo.com/v8/finance/chart/$tk?interval=1d", "https://query1.finance.yahoo.com/v8/finance/chart/$tk")) {
        try {
            $res = Invoke-RestMethod -Uri $u -Headers $headers -TimeoutSec 6
            $m = $res.chart.result[0].meta
            $price = [double]($m.regularMarketPrice)
            if (-not $price -or $price -le 0) { $price = [double]($m.chartPreviousClose) }
            if (-not $price -or $price -le 0) { $price = [double]($m.previousClose) }
            
            if ($price -and $price -gt 0) {
                $pricesData[$tk] = [math]::Round($price, 2)
                Write-Host "  Price OK: $tk = $price"
                $tkSuccess = $true
                break
            }
        } catch {}
    }
    if (-not $tkSuccess) {
        Write-Host "  Price FAIL: $tk"
    }
}

$nowUtc = [DateTime]::UtcNow
$thaiTz = [TimeZoneInfo]::FindSystemTimeZoneById("SE Asia Standard Time")
$nowThai = [TimeZoneInfo]::ConvertTimeFromUtc($nowUtc, $thaiTz)
$thaiYear = $nowThai.Year + 543
$timeHHmm = $nowThai.ToString("HH:mm")
$thaiStr = "$($nowThai.Day) " + [char]0x0E15 + "." + [char]0x0E04 + ". " + "$thaiYear $timeHHmm " + [char]0x0E19 + "."

$outputObj = [ordered]@{
    updated_at = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    updated_at_thai = $thaiStr
    fx = [ordered]@{
        USDTHB = $usdThb
    }
    indices = $indicesData
    prices = $pricesData
}

$json = $outputObj | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($pricesFile, $json, [System.Text.Encoding]::UTF8)

Write-Host "Done! Updated data/prices.json at $thaiStr with $($pricesData.Count) tickers!"
