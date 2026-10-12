# ==============================================================================
# scripts/update_news.ps1
# Fetches live financial & market news from CNBC & Yahoo Finance
# Translates, categorizes, detects sentiment, and generates data/news.json
# ==============================================================================
$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir
$newsFile = Join-Path $repoDir "data\news.json"

Write-Host "Updating Market News: $newsFile"

$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

$tickerMap = @{
    "NVDA" = @("NVIDIA", "NVDA", "BLACKWELL", "GEFORCE", "JENSEN HUANG")
    "AAPL" = @("APPLE", "AAPL", "IPHONE", "TIM COOK", "IOS")
    "MSFT" = @("MICROSOFT", "MSFT", "AZURE", "SATYA NADELLA", "WINDOWS")
    "GOOGL" = @("GOOGLE", "ALPHABET", "GOOGL", "GOOG", "GEMINI", "YOUTUBE")
    "AMZN" = @("AMAZON", "AMZN", "AWS", "BEZOS")
    "META" = @("META", "FACEBOOK", "ZUCKERBERG", "INSTAGRAM")
    "TSLA" = @("TESLA", "TSLA", "ELON MUSK", "CYBERTRUCK", "CYBERCAB", "ROBOVAN")
    "AMD" = @("AMD", "ADVANCED MICRO DEVICES", "LISA SU")
    "INTC" = @("INTEL", "INTC", "GELSINGER")
    "TSM" = @("TSMC", "TSM", "TAIWAN SEMICONDUCTOR")
    "SPY" = @("S&P 500", "SPY", "SP500")
    "QQQ" = @("NASDAQ", "QQQ", "TECH STOCKS")
    "DIA" = @("DOW JONES", "DIA", "DOW")
    "TLT" = @("TREASURY", "BONDS", "10-YEAR", "BOND YIELD", "TLT")
    "JPM" = @("JPMORGAN", "JPM", "JAMIE DIMON")
    "GS" = @("GOLDMAN SACHS", "GS")
    "BAC" = @("BANK OF AMERICA", "BAC")
    "WFC" = @("WELLS FARGO", "WFC")
    "XOM" = @("EXXON", "EXXONMOBIL", "XOM")
    "CVX" = @("CHEVRON", "CVX")
    "LLY" = @("ELI LILLY", "LLY", "MOUNJARO", "ZEPBOUND")
    "NVO" = @("NOVO NORDISK", "NVO", "OZEMPIC", "WEGOVY")
    "CRM" = @("SALESFORCE", "CRM")
    "NFLX" = @("NETFLIX", "NFLX")
    "COIN" = @("COINBASE", "COIN", "BITCOIN", "CRYPTO")
    "PLTR" = @("PALANTIR", "PLTR")
    "SCHD" = @("SCHD", "DIVIDEND")
    "VOO" = @("VOO")
    "VTI" = @("VTI")
}

function Translate-ToThai($text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    try {
        $encoded = [System.Uri]::EscapeDataString($text.Trim())
        $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=th&dt=t&q=$encoded"
        $res = Invoke-RestMethod -Uri $url -TimeoutSec 5
        $translated = ($res[0] | ForEach-Object { $_[0] }) -join ""
        if (-not [string]::IsNullOrWhiteSpace($translated)) { return $translated.Trim() }
    } catch {}
    return $text.Trim()
}

function Get-RelativeTimeThai($diffSeconds) {
    if ($diffSeconds -lt 60) { return "เมื่อสักครู่" }
    $mins = [math]::Floor($diffSeconds / 60)
    if ($mins -lt 60) { return "$mins นาทีที่แล้ว" }
    $hours = [math]::Floor($mins / 60)
    if ($hours -lt 24) { return "$hours ชั่วโมงที่แล้ว" }
    $days = [math]::Floor($hours / 24)
    return "$days วันที่แล้ว"
}

function Detect-Sentiment($text) {
    $upper = $text.ToUpper()
    $bullishWords = @("SURGE", "JUMP", "GAIN", "RISE", "RALLY", "RECORD", "HIGH", "BEAT", "BOOST", "UPGRADE", "PROFIT", "GROWTH", "SOAR", "STRONG", "BULL", "OUTPERFORM", "CLIMB", "UPSIDE", "REBOUND")
    $bearishWords = @("PLUNGE", "DROP", "FALL", "SLUMP", "TUMBLE", "MISS", "DOWNGRADE", "LOSS", "DECLINE", "SINK", "WARN", "BEAR", "RISK", "RECESSION", "CRASH", "DOWN", "SELLOFF", "PRESSURE")
    
    $bullCount = 0
    foreach ($w in $bullishWords) { if ($upper.Contains($w)) { $bullCount++ } }
    $bearCount = 0
    foreach ($w in $bearishWords) { if ($upper.Contains($w)) { $bearCount++ } }

    if ($bullCount -gt $bearCount) { return "BULLISH" }
    if ($bearCount -gt $bullCount) { return "BEARISH" }
    return "NEUTRAL"
}

function Detect-Category($text, $feedCat) {
    $upper = $text.ToUpper()
    if ($upper.Contains("OIL") -or $upper.Contains("CRUDE") -or $upper.Contains("OPEC") -or $upper.Contains("COMMODIT") -or $upper.Contains("GOLD") -or $upper.Contains("GAS")) {
        return "COMMODITIES"
    }
    if ($upper.Contains("EARNING") -or $upper.Contains("REVENUE") -or $upper.Contains("PROFIT") -or $upper.Contains("QUARTER") -or $upper.Contains("RESULTS") -or $upper.Contains("Q3") -or $upper.Contains("Q4") -or $upper.Contains("GUIDANCE")) {
        return "EARNINGS"
    }
    if ($upper.Contains("FED") -or $upper.Contains("POWELL") -or $upper.Contains("INFLATION") -or $upper.Contains("CPI") -or $upper.Contains("INTEREST RATE") -or $upper.Contains("RATE CUT") -or $upper.Contains("TREASURY") -or $upper.Contains("ECONOMY") -or $upper.Contains("JOBS")) {
        return "MACRO"
    }
    if ($upper.Contains("AI") -or $upper.Contains("CHIP") -or $upper.Contains("TECH") -or $upper.Contains("SEMICONDUCTOR") -or $upper.Contains("SOFTWARE") -or $upper.Contains("CLOUD") -or $upper.Contains("NVIDIA") -or $upper.Contains("APPLE") -or $upper.Contains("MICROSOFT")) {
        return "TECH"
    }
    return $feedCat
}

function Detect-Tickers($text) {
    $upper = $text.ToUpper()
    $detected = [System.Collections.Generic.List[string]]::new()
    foreach ($sym in $tickerMap.Keys) {
        $keywords = $tickerMap[$sym]
        foreach ($k in $keywords) {
            if ($upper.Contains(" " + $k + " ") -or $upper.StartsWith($k + " ") -or $upper.EndsWith(" " + $k) -or $upper.Contains("(" + $k + ")") -or $upper.Contains("#" + $k) -or ($k.Length -ge 4 -and $upper.Contains($k))) {
                if (-not $detected.Contains($sym)) {
                    $detected.Add($sym)
                }
                break
            }
        }
    }
    return $detected
}

$rawArticles = [System.Collections.Generic.List[PSObject]]::new()

# 1. Fetch CNBC Feeds
$cnbcFeeds = [ordered]@{
    "MACRO" = "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=10000664"
    "TECH" = "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=19854910"
    "MACRO_ECON" = "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=20910258"
    "EARNINGS" = "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=15839135"
}

foreach ($cat in $cnbcFeeds.Keys) {
    $feedUrl = $cnbcFeeds[$cat]
    $mappedCat = if ($cat -eq "MACRO_ECON") { "MACRO" } else { $cat }
    try {
        $res = Invoke-WebRequest -Uri $feedUrl -Headers $headers -UseBasicParsing -TimeoutSec 8
        [xml]$xml = $res.Content
        $items = $xml.rss.channel.item
        if ($items) {
            $count = 0
            foreach ($it in $items) {
                if ($count -ge 6) { break }
                $title = [string]$it.title
                $link = [string]$it.link
                $pubDateStr = [string]$it.pubDate
                $desc = ""
                if ($it.description) {
                    if ($it.description.InnerText) {
                        $desc = [string]$it.description.InnerText
                    } elseif ($it.description.'#cdata-section') {
                        $desc = [string]$it.description.'#cdata-section'
                    }
                }
                if ([string]::IsNullOrWhiteSpace($desc) -or $desc -eq "System.Xml.XmlElement") {
                    $desc = $title
                }

                if (-not [string]::IsNullOrWhiteSpace($title) -and -not [string]::IsNullOrWhiteSpace($link)) {
                    $publishedAt = [DateTimeOffset]::UtcNow
                    try {
                        $publishedAt = [DateTimeOffset]::Parse($pubDateStr)
                    } catch {}

                    $rawArticles.Add([PSCustomObject]@{
                        title = $title.Trim()
                        summary = if (-not [string]::IsNullOrWhiteSpace($desc)) { $desc.Trim() } else { $title.Trim() }
                        source = "CNBC"
                        sourceUrl = $link.Trim()
                        publishedAt = $publishedAt
                        defaultCat = $mappedCat
                    })
                    $count++
                }
            }
        }
    } catch {
        Write-Host "Warning: Could not fetch CNBC $cat"
    }
}

# 2. Fetch Yahoo Finance News
$yahooQueries = @("stock market", "Federal Reserve interest rate", "artificial intelligence tech", "crude oil")
foreach ($q in $yahooQueries) {
    try {
        $escapedQ = [System.Uri]::EscapeDataString($q)
        $yUrl = "https://query2.finance.yahoo.com/v1/finance/search?q=$escapedQ&newsCount=5"
        $yRes = Invoke-RestMethod -Uri $yUrl -Headers $headers -TimeoutSec 8
        if ($yRes -and $yRes.news) {
            foreach ($n in $yRes.news) {
                $title = [string]$n.title
                $link = [string]$n.link
                $publisher = if (-not [string]::IsNullOrWhiteSpace($n.publisher)) { $n.publisher.Trim() } else { "Yahoo Finance" }
                if (-not [string]::IsNullOrWhiteSpace($title) -and -not [string]::IsNullOrWhiteSpace($link)) {
                    $publishedAt = [DateTimeOffset]::UtcNow
                    if ($n.providerPublishTime) {
                        try {
                            $publishedAt = [DateTimeOffset]::FromUnixTimeSeconds([long]$n.providerPublishTime)
                        } catch {}
                    }
                    $rawArticles.Add([PSCustomObject]@{
                        title = $title.Trim()
                        summary = $title.Trim()
                        source = $publisher
                        sourceUrl = $link.Trim()
                        publishedAt = $publishedAt
                        defaultCat = "ALL"
                    })
                }
            }
        }
    } catch {
        Write-Host "Warning: Yahoo Finance query $q failed"
    }
}

Write-Host "Total raw articles: $($rawArticles.Count)"

$seenUrls = [System.Collections.Generic.HashSet[string]]::new()
$uniqueArticles = [System.Collections.Generic.List[PSObject]]::new()

foreach ($art in $rawArticles) {
    $normUrl = $art.sourceUrl.Split('?')[0].ToLower()
    $normTitle = $art.title.ToLower()
    if (-not $seenUrls.Contains($normUrl) -and -not $seenUrls.Contains($normTitle)) {
        $seenUrls.Add($normUrl) | Out-Null
        $seenUrls.Add($normTitle) | Out-Null
        $uniqueArticles.Add($art)
    }
}

$sortedArticles = $uniqueArticles | Sort-Object -Property { $_.publishedAt } -Descending
$selected = $sortedArticles | Select-Object -First 12

$nowUtc = [DateTimeOffset]::UtcNow
$processedNews = [System.Collections.Generic.List[object]]::new()
$idCounter = 1

Write-Host "Processing top $($selected.Count) articles..."

foreach ($item in $selected) {
    $diffSec = [math]::Max(0, [long]($nowUtc - $item.publishedAt).TotalSeconds)
    $timeThai = Get-RelativeTimeThai $diffSec

    $displayTitle = if ($item.title.Length -gt 45) { $item.title.Substring(0, 45) } else { $item.title }
    Write-Host "[$idCounter] Translating: $displayTitle..."
    $thTitle = Translate-ToThai $item.title
    $thSummary = if ($item.summary -ne $item.title) { Translate-ToThai $item.summary } else { $thTitle }

    $combinedEn = "$($item.title) $($item.summary)"
    $category = Detect-Category $combinedEn $item.defaultCat
    $tickers = Detect-Tickers $combinedEn
    if ($tickers.Count -eq 0) {
        if ($category -eq "MACRO") { $tickers = @("SPY", "QQQ", "TLT") }
        elseif ($category -eq "TECH") { $tickers = @("NVDA", "AAPL", "MSFT") }
        elseif ($category -eq "COMMODITIES") { $tickers = @("XOM", "CVX") }
        elseif ($category -eq "EARNINGS") { $tickers = @("SPY", "DIA") }
        else { $tickers = @("SPY") }
    }

    $sentiment = Detect-Sentiment $combinedEn
    $impact = switch ($sentiment) {
        "BULLISH" { "เชิงบวกต่อบรรยากาศการลงทุนและสินทรัพย์เสี่ยง" }
        "BEARISH" { "ปัจจัยความเสี่ยงที่ต้องติดตามความผันผวน" }
        Default   { "เกาะติดความคืบหน้าและประเมินทิศทางตลาด" }
    }

    $formattedPub = $item.publishedAt.ToString("dd/MM/yyyy HH:mm")
    $tickerTagStr = ($tickers | ForEach-Object { "#" + $_ }) -join " "

    $points = @(
        $thSummary,
        "แหล่งข่าวอ้างอิง: $($item.source) ($formattedPub UTC)",
        "กลุ่มสินทรัพย์และหุ้นที่เกี่ยวข้อง: $tickerTagStr"
    )

    $fullArticle = @(
        $thTitle,
        $thSummary,
        "รายงานต้นฉบับภาษาอังกฤษระบุว่า: `"$($item.title)`" ซึ่งนักวิเคราะห์ในตลาดกำลังจับตาดูผลกระทบต่อทิศทางราคาและผลตอบแทนในระยะสั้นถึงระยะกลาง"
    )

    $processedNews.Add([ordered]@{
        id = "news-$idCounter"
        title = $thTitle
        title_en = $item.title
        summary = $thSummary
        source = $item.source
        sourceUrl = $item.sourceUrl
        time = $timeThai
        publishedAt = $item.publishedAt.ToString("yyyy-MM-ddTHH:mm:ssZ")
        category = $category
        tickers = @($tickers)
        sentiment = $sentiment
        impact = $impact
        isHero = ($idCounter -eq 1)
        points = $points
        fullArticle = $fullArticle
    })

    $idCounter++
}

$thaiTz = [TimeZoneInfo]::FindSystemTimeZoneById("SE Asia Standard Time")
$nowThai = [TimeZoneInfo]::ConvertTimeFromUtc($nowUtc.UtcDateTime, $thaiTz)
$thaiYear = $nowThai.Year + 543
$timeHHmm = $nowThai.ToString("HH:mm")
$thaiMonths = @("", "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค.")
$thaiDateStr = "$($nowThai.Day) " + $thaiMonths[$nowThai.Month] + " $thaiYear $timeHHmm น."

$outputObject = [ordered]@{
    updated_at = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    updated_at_thai = $thaiDateStr
    news_count = $processedNews.Count
    news = $processedNews
}

$jsonString = $outputObject | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($newsFile, $jsonString, [System.Text.Encoding]::UTF8)

Write-Host "Successfully generated $newsFile with $($processedNews.Count) live curated news items!"