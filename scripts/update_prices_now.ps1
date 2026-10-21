$ErrorActionPreference = "Continue"

$tickers = @(
    "GOOGL", "MSFT", "JEPI", "JEPQ", "VTI", 
    "VOO", "QQQ", "QQQM", "SCHD", "AAPL", 
    "NVDA", "VXUS", "SPY", "AMZN", "META", 
    "TSLA", "AMD", "NFLX", "COIN", "PLTR", 
    "SOXX", "SMH", "INTC", "BRK-B", "GRID", 
    "SPMO", "XLV", "SPYD", "VRT", "CIEN", 
    "CRWD", "LLY", "MU"
)

$indicesConfig = @{
    "^DJI" = "Dow Jones"
    "^GSPC" = "S&P 500"
    "^IXIC" = "Nasdaq"
    "^NDX" = "NDX 100"
    "^VIX" = "VIX Index"
    "GC=F" = "Gold (XAU)"
    "CL=F" = "WTI Crude Oil"
    "DX-Y.NYB" = "DXY Index"
}

$pricesFile = Join-Path $PSScriptRoot "..\data\prices.json"
$existing = Get-Content $pricesFile -Raw -Encoding UTF8 | ConvertFrom-Json

$prices = @{}
if ($existing.prices) {
    foreach ($prop in $existing.prices.psobject.Properties) {
        $prices[$prop.Name] = $prop.Value
    }
}

$indices = @{}
if ($existing.indices) {
    foreach ($prop in $existing.indices.psobject.Properties) {
        $indices[$prop.Name] = $prop.Value
    }
}

$extended = @{}
if ($existing.extended_hours) {
    foreach ($prop in $existing.extended_hours.psobject.Properties) {
        $extended[$prop.Name] = $prop.Value
    }
}

Write-Host "Updating stock prices via Yahoo Finance API..."
foreach ($tk in $tickers) {
    $sym = $tk.Replace(".", "-")
    $url = "https://query1.finance.yahoo.com/v8/finance/chart/$sym"
    try {
        $raw = curl.exe -s -m 5 $url -H "User-Agent: Mozilla/5.0"
        if ($raw) {
            $json = $raw | ConvertFrom-Json
            if ($json.chart.result -and $json.chart.result.Count -gt 0) {
                $meta = $json.chart.result[0].meta
                $p = $meta.regularMarketPrice
                if (-not $p) { $p = $meta.chartPreviousClose }
                if (-not $p) { $p = $meta.previousClose }
                if ($p) {
                    $pNum = [Math]::Round([double]$p, 4)
                    $prices[$tk] = $pNum
                    if ($tk -like "*-*") { $prices[$tk.Replace("-", ".")] = $pNum }
                    if ($tk -like "*.*") { $prices[$tk.Replace(".", "-")] = $pNum }
                    Write-Host "  [OK] $tk = $pNum"
                }
            }
        }
    } catch {
        Write-Host "  [ERR] $tk"
    }
}

Write-Host "Updating Indices..."
foreach ($idxKey in $indicesConfig.Keys) {
    $url = "https://query1.finance.yahoo.com/v8/finance/chart/$idxKey"
    try {
        $raw = curl.exe -s -m 5 $url -H "User-Agent: Mozilla/5.0"
        if ($raw) {
            $json = $raw | ConvertFrom-Json
            if ($json.chart.result -and $json.chart.result.Count -gt 0) {
                $meta = $json.chart.result[0].meta
                $p = $meta.regularMarketPrice
                $prev = $meta.chartPreviousClose
                if (-not $prev) { $prev = $meta.previousClose }
                if ($p) {
                    $pVal = [Math]::Round([double]$p, 2)
                    $prevVal = if ($prev) { [Math]::Round([double]$prev, 2) } else { $pVal }
                    $diff = [Math]::Round($pVal - $prevVal, 2)
                    $pct = if ($prevVal -gt 0) { [Math]::Round(($diff / $prevVal) * 100, 2) } else { 0.0 }
                    $indices[$idxKey] = @{
                        price = $pVal
                        prevClose = $prevVal
                        change = $diff
                        changePct = $pct
                        name = $indicesConfig[$idxKey]
                    }
                    Write-Host "  [OK Index] $($indicesConfig[$idxKey]) = $pVal ($pct%)"
                }
            }
        }
    } catch {
        Write-Host "  [ERR Index] $idxKey"
    }
}

Write-Host "Updating USD/THB..."
$fxVal = 33.57
try {
    $raw = curl.exe -s -m 5 "https://query1.finance.yahoo.com/v8/finance/chart/THB=X" -H "User-Agent: Mozilla/5.0"
    if ($raw) {
        $json = $raw | ConvertFrom-Json
        $fx = $json.chart.result[0].meta.regularMarketPrice
        if ($fx) { $fxVal = [Math]::Round([double]$fx, 4) }
    }
} catch {}
Write-Host "  USD/THB = $fxVal"

$nowUtc = [DateTime]::UtcNow
$nowThai = $nowUtc.AddHours(7)
$thaiMonthChar = [string][char]0x0E15 + [string][char]0x0E04 + "."
$thaiNahChar = [string][char]0x0E19 + "."
$thaiStr = "$($nowThai.Day) $thaiMonthChar $($nowThai.Year + 543) $($nowThai.ToString('HH:mm')) $thaiNahChar"

$finalObj = [ordered]@{
    updated_at = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    updated_at_thai = $thaiStr
    fx = @{
        USDTHB = $fxVal
    }
    indices = $indices
    prices = $prices
    extended_hours = $extended
}

$finalJson = $finalObj | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText((Resolve-Path $pricesFile), $finalJson, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Successfully written to prices.json at $thaiStr"
