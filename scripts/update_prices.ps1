# PowerShell script to update stock prices, indices, and FX
$ErrorActionPreference = "Continue"

$pricesFile = Join-Path $PSScriptRoot "..\data\prices.json"
$existingData = @{}
if (Test-Path $pricesFile) {
    try {
        $existingData = Get-Content $pricesFile -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    } catch {}
}

$tickers = @(
    "GOOGL", "MSFT", "JEPI", "JEPQ", "VTI", 
    "VOO", "QQQ", "QQQM", "SCHD", "AAPL", 
    "NVDA", "VXUS", "SPY", "AMZN", "META", 
    "TSLA", "AMD", "NFLX", "COIN", "PLTR", 
    "SOXX", "SMH", "INTC", "BRK-B"
)

if ($existingData.prices) {
    foreach ($k in $existingData.prices.Keys) {
        if ($k -and $k -ne "CASH" -and -not ($tickers -contains $k)) {
            $tickers += $k
        }
    }
}
$tickers = $tickers | Sort-Object -Unique

$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

$nowUtc = [DateTimeOffset]::UtcNow
$nowTs = $nowUtc.ToUnixTimeSeconds()

$prices = @{}
$extendedHours = @{}

Write-Host "Updating $($tickers.Count) tickers..."

foreach ($tk in $tickers) {
    $sym = $tk.Replace(".", "-")
    $url = "https://query1.finance.yahoo.com/v8/finance/chart/$sym`?range=1d&interval=1m&includePrePost=true"
    
    try {
        $res = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 5
        if ($res -and $res.chart -and $res.chart.result) {
            $result = $res.chart.result[0]
            $meta = $result.meta
            $regPrice = if ($meta.regularMarketPrice) { $meta.regularMarketPrice } else { $meta.chartPreviousClose }
            if ($regPrice) {
                $regPrice = [Math]::Round([double]$regPrice, 2)
                $prices[$tk] = $regPrice
                
                $periods = $meta.currentTradingPeriod
                $preP = if ($periods) { $periods.pre } else { $null }
                $regP = if ($periods) { $periods.regular } else { $null }
                $postP = if ($periods) { $periods.post } else { $null }
                
                $session = $null
                if ($preP -and $regP -and ($nowTs -ge $preP.start) -and ($nowTs -lt $regP.start)) {
                    $session = "PRE"
                } elseif ($regP -and $postP -and ($nowTs -ge $regP.end) -and ($nowTs -le $postP.end)) {
                    $session = "POST"
                }
                
                if ($session) {
                    $timestamps = $result.timestamp
                    $quotes = $result.indicators.quote[0].close
                    $sessionPrice = $null
                    
                    if ($quotes -and $timestamps) {
                        for ($i = $quotes.Count - 1; $i -ge 0; $i--) {
                            if ($quotes[$i] -ne $null) {
                                $ts = $timestamps[$i]
                                if ($session -eq "PRE" -and $preP.start -and ($ts -ge $preP.start)) {
                                    $sessionPrice = $quotes[$i]
                                    break
                                } elseif ($session -eq "POST" -and $regP.end -and ($ts -ge $regP.end)) {
                                    $sessionPrice = $quotes[$i]
                                    break
                                }
                            }
                        }
                    }
                    if ($sessionPrice -eq $null) {
                        if ($session -eq "PRE") {
                            $sessionPrice = if ($meta.preMarketPrice) { $meta.preMarketPrice } else { $meta.fulldayPrice }
                        } else {
                            $sessionPrice = if ($meta.postMarketPrice) { $meta.postMarketPrice } else { $meta.fulldayPrice }
                        }
                    }
                    
                    if ($sessionPrice -and ([Math]::Abs([double]$sessionPrice - [double]$regPrice) -gt 0.0001)) {
                        $sPrice = [Math]::Round([double]$sessionPrice, 2)
                        $diff = [Math]::Round($sPrice - $regPrice, 2)
                        $pct = [Math]::Round(($diff / $regPrice) * 100, 2)
                        $extendedHours[$tk] = @{
                            session = $session
                            price = $sPrice
                            regularPrice = $regPrice
                            change = $diff
                            changePct = $pct
                            time = $nowTs
                        }
                        Write-Host "  [OK] $tk : $regPrice (${session}: `$$sPrice $pct%)"
                    } else {
                        Write-Host "  [OK] $tk : $regPrice (No extended gap)"
                    }
                } else {
                    Write-Host "  [OK] $tk : $regPrice (Session: Regular/Closed)"
                }
                continue
            }
        }
    } catch {
        Write-Host "  [FAIL] $tk : $_"
    }
    
    # Fallback to existing
    if ($existingData.prices -and $existingData.prices[$tk]) {
        $prices[$tk] = $existingData.prices[$tk]
    }
}

# FX Rate
Write-Host "Fetching USD/THB rate..."
$usdThb = 33.50
try {
    $fxUrl = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json"
    $fxRes = Invoke-RestMethod -Uri $fxUrl -TimeoutSec 3
    if ($fxRes -and $fxRes.usd -and $fxRes.usd.thb) {
        $usdThb = [Math]::Round([double]$fxRes.usd.thb, 4)
    }
} catch {
    if ($existingData.fx -and $existingData.fx.USDTHB) { $usdThb = $existingData.fx.USDTHB }
}
Write-Host "  USD/THB: $usdThb"

# Indices
Write-Host "Fetching market indices..."
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
$indices = @{}
foreach ($sym in $indicesConfig.Keys) {
    $name = $indicesConfig[$sym]
    $iUrl = "https://query1.finance.yahoo.com/v8/finance/chart/$sym`?interval=1d"
    try {
        $iRes = Invoke-RestMethod -Uri $iUrl -Headers $headers -TimeoutSec 4
        if ($iRes -and $iRes.chart -and $iRes.chart.result) {
            $iMeta = $iRes.chart.result[0].meta
            $pr = if ($iMeta.regularMarketPrice) { $iMeta.regularMarketPrice } else { $iMeta.chartPreviousClose }
            $prev = if ($iMeta.chartPreviousClose) { $iMeta.chartPreviousClose } else { $pr }
            if ($pr) {
                $pr = [Math]::Round([double]$pr, 2)
                $prev = [Math]::Round([double]$prev, 2)
                $diff = [Math]::Round($pr - $prev, 2)
                $pct = if ($prev -gt 0) { [Math]::Round(($diff / $prev) * 100, 2) } else { 0 }
                $indices[$sym] = @{
                    name = $name
                    price = $pr
                    prevClose = $prev
                    change = $diff
                    changePct = $pct
                }
                Write-Host "  [OK Index] $name ($sym): $pr ($pct%)"
                continue
            }
        }
    } catch {
        Write-Host "  [FAIL Index] $name ($sym)"
    }
    if ($existingData.indices -and $existingData.indices[$sym]) {
        $indices[$sym] = $existingData.indices[$sym]
    }
}

# Thai date format
$thaiTime = $nowUtc.ToOffset([TimeSpan]::FromHours(7))
$thMonths = @("", "$([char]0x0E21).$([char]0x0E04).", "$([char]0x0E01).$([char]0x0E1E).", "$([char]0x0E21).$([char]0x0E35).$([char]0x0E04).", "$([char]0x0E40).$([char]0x0E21).$([char]0x0E22).", "$([char]0x0E1E).$([char]0x0E04).", "$([char]0x0E21).$([char]0x0E34).$([char]0x0E22).", "$([char]0x0E01).$([char]0x0E04).", "$([char]0x0E2A).$([char]0x0E04).", "$([char]0x0E01).$([char]0x0E22).", "$([char]0x0E15).$([char]0x0E04).", "$([char]0x0E1E).$([char]0x0E22).", "$([char]0x0E18).$([char]0x0E04).")
$mName = $thMonths[$thaiTime.Month]
$bYear = $thaiTime.Year + 543
$tTime = $thaiTime.ToString("HH:mm")
$thaiStr = "$($thaiTime.Day) $mName $bYear $tTime $([char]0x0E19)."

$finalOutput = [ordered]@{
    updated_at = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    updated_at_thai = $thaiStr
    fx = @{
        USDTHB = $usdThb
    }
    indices = $indices
    prices = $prices
    extended_hours = $extendedHours
}

$jsonStr = $finalOutput | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($pricesFile, $jsonStr, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Successfully saved $pricesFile at $thaiStr"
