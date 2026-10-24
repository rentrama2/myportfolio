# ==============================================================================
# scripts/update_news.ps1
# Fetches live financial & market news from CNBC & Yahoo Finance
# Translates with entity protection, categorizes, detects sentiment,
# and generates structured high-quality Thai news to data/news.json
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

$protectTerms = @(
    @("Credit Default Swaps", "__ENT_CDS__"),
    @("Credit default swaps", "__ENT_CDS__"),
    @("credit default swaps", "__ENT_CDS__"),
    @("Free Cash Flow", "__ENT_FCF__"),
    @("free cash flow", "__ENT_FCF__"),
    @("Rocket Lab", "__ENT_ROCKETLAB__"),
    @("Simply Wall St.", "__ENT_SIMPLYWALLST__"),
    @("Stocktwits", "__ENT_STOCKTWITS__"),
    @("Solidigm", "__ENT_SOLIDIGM__"),
    @("Alphabet", "__ENT_ALPHABET__"),
    @("Google", "__ENT_GOOGLE__"),
    @("Starlink", "__ENT_STARLINK__"),
    @("Starshield", "__ENT_STARSHIELD__"),
    @("SpaceX", "__ENT_SPACEX__"),
    @("Nokia", "__ENT_NOKIA__"),
    @("ICEYE", "__ENT_ICEYE__"),
    @("Volvo Cars", "__ENT_VOLVOCARS__"),
    @("Volvo", "__ENT_VOLVO__"),
    @("Saab", "__ENT_SAAB__"),
    @("Gripen", "__ENT_GRIPEN__"),
    @("iPhone Duo", "__ENT_IPHONEDUO__"),
    @("iPhone", "__ENT_IPHONE__"),
    @("S&P 500", "__ENT_SP500__"),
    @("Dow Jones", "__ENT_DOWJONES__"),
    @("Nasdaq", "__ENT_NASDAQ__"),
    @("Russell 2000", "__ENT_RUSSELL2000__"),
    @("Federal Reserve", "__ENT_FED__"),
    @("Fed", "__ENT_FED__"),
    @("Jerome Powell", "__ENT_POWELL__"),
    @("Powell", "__ENT_POWELL__"),
    @("Donald Trump", "__ENT_TRUMP__"),
    @("Trump", "__ENT_TRUMP__"),
    @("Elon Musk", "__ENT_ELONMUSK__"),
    @("Musk", "__ENT_MUSK__"),
    @("Tim Cook", "__ENT_TIMCOOK__"),
    @("Jensen Huang", "__ENT_JENSENHUANG__"),
    @("Satya Nadella", "__ENT_SATYANADELLA__"),
    @("TPU", "__ENT_TPU__"),
    @("IPO", "__ENT_IPO__"),
    @("CDS", "__ENT_CDS__"),
    @("FCF", "__ENT_FCF__"),
    @("Scalpers", "__ENT_SCALPERS__"),
    @("scalpers", "__ENT_SCALPERS__"),
    @("Neoclouds", "__ENT_NEOCLOUDS__"),
    @("neoclouds", "__ENT_NEOCLOUDS__"),
    @("Hyperscalers", "__ENT_HYPERSCALERS__"),
    @("hyperscalers", "__ENT_HYPERSCALERS__"),
    @("Midterms", "__ENT_MIDTERMS__"),
    @("midterms", "__ENT_MIDTERMS__")
)

$restoreMap = @{
    "__ENT_ALPHABET__" = "Alphabet"
    "__ENT_GOOGLE__" = "Google"
    "__ENT_ROCKETLAB__" = "Rocket Lab"
    "__ENT_SIMPLYWALLST__" = "Simply Wall St."
    "__ENT_STOCKTWITS__" = "Stocktwits"
    "__ENT_SOLIDIGM__" = "Solidigm"
    "__ENT_STARLINK__" = "Starlink"
    "__ENT_STARSHIELD__" = "Starshield"
    "__ENT_SPACEX__" = "SpaceX"
    "__ENT_NOKIA__" = "Nokia"
    "__ENT_ICEYE__" = "ICEYE"
    "__ENT_VOLVOCARS__" = "Volvo Cars"
    "__ENT_VOLVO__" = "Volvo"
    "__ENT_SAAB__" = "Saab"
    "__ENT_GRIPEN__" = "เครื่องบินขับไล่ Gripen"
    "__ENT_IPHONEDUO__" = "Apple iPhone Duo"
    "__ENT_IPHONE__" = "iPhone"
    "__ENT_SP500__" = "S&P 500"
    "__ENT_DOWJONES__" = "Dow Jones"
    "__ENT_NASDAQ__" = "Nasdaq"
    "__ENT_RUSSELL2000__" = "Russell 2000"
    "__ENT_FED__" = "เฟด (Fed)"
    "__ENT_POWELL__" = "พาวเวลล์ (Powell)"
    "__ENT_TRUMP__" = "ทรัมป์ (Trump)"
    "__ENT_ELONMUSK__" = "อีลอน มัสก์ (Elon Musk)"
    "__ENT_MUSK__" = "มัสก์ (Musk)"
    "__ENT_TIMCOOK__" = "ทิม คุก (Tim Cook)"
    "__ENT_JENSENHUANG__" = "เจนเซ่น หวง (Jensen Huang)"
    "__ENT_SATYANADELLA__" = "สัตยา นาเดลลา (Satya Nadella)"
    "__ENT_CDS__" = "สัญญาประกันหนี้เสีย (CDS)"
    "__ENT_TPU__" = "ชิป TPU"
    "__ENT_IPO__" = "IPO"
    "__ENT_FCF__" = "กระแสเงินสดอิสระ (Free Cash Flow)"
    "__ENT_SCALPERS__" = "กลุ่มพ่อค้าเก็งกำไร (Scalpers)"
    "__ENT_NEOCLOUDS__" = "กลุ่ม Neoclouds"
    "__ENT_HYPERSCALERS__" = "กลุ่มผู้ให้บริการคลาวด์ยักษ์ใหญ่ (Hyperscalers)"
    "__ENT_MIDTERMS__" = "การเลือกตั้งกลางเทอม (Midterms)"
}

function Protect-Entities($text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    $result = $text
    foreach ($item in $protectTerms) {
        $term = $item[0]
        $token = $item[1]
        $result = [regex]::Replace($result, "\b" + [regex]::Escape($term) + "\b", $token)
    }
    return $result
}

function Polish-ThaiFinancialText($text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    $res = $text

    foreach ($key in $restoreMap.Keys) {
        $val = $restoreMap[$key]
        $res = $res.Replace($key, $val)
        $spacedKey = $key.Replace("_", "\s*_\s*")
        $res = [regex]::Replace($res, $spacedKey, $val, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    $replacements = @(
        @("\bตัวอักษร\s*\((?:GOOGL|GOOG)\)", "Alphabet (GOOGL)"),
        @("ตัวอักษร\s*\(\s*GOOGL\s*\)", "Alphabet (GOOGL)"),
        @("ผู้ถลกหนัง", "กลุ่มพ่อค้าเก็งกำไร (Scalpers)"),
        @("สัญญาแลกเปลี่ยนเครดิตเริ่มต้น", "สัญญาประกันการผิดนัดชำระหนี้ (Credit Default Swaps / CDS)"),
        @("การดึง\s*IPO", "การระงับแผนเข้าตลาดหุ้น IPO"),
        @("ดึง\s*IPO", "ถอนการยื่นเสนอขายหุ้น IPO"),
        @("การบรรยายสรุป", "สรุปภาพรวม"),
        @("ตัวขับเคลื่อนตลาด", "ปัจจัยขับเคลื่อนตลาด"),
        @("ทำให้เกิดความกลัวต่อ", "สร้างความกังวลต่อ"),
        @("ทำให้เกิดความกลัว", "จุดชนวนความกังวล"),
        @("การสร้าง\s*AI", "การขยายโครงสร้างพื้นฐาน AI (AI Build-out)"),
        @("เบื้องหลังความต้องการ", "เพื่อรองรับอุปสงค์"),
        @("เมื่อถึงกลางภาค", "ก่อนการเลือกตั้งกลางเทอม (Midterms)"),
        @("คะแนนการอนุมัติ", "คะแนนความนิยม (Approval Rating)"),
        @("ยุติธรรมหรือยากจน", "ปานกลางถึงย่ำแย่"),
        @("ในการตามล่าหา", "ในการมองหาทางเลือกทดแทน"),
        @("ส่งผลเสียต่อกระแสเงินสดอิสระ", "กดดันกระแสเงินสดอิสระ (Free Cash Flow)"),
        @("ไฮเปอร์สเกลเลอร์", "ผู้ให้บริการคลาวด์ยักษ์ใหญ่ (Hyperscalers)"),
        @("นีโอคลาวด์", "กลุ่มผู้ให้บริการคลาวด์รุ่นใหม่ (Neoclouds)"),
        @("การตกต่ำของหุ้น", "การปรับตัวลงของราคาหุ้น"),
        @("สเปรดที่เพิ่มขึ้น", "ส่วนต่างอัตราผลตอบแทน (Credit Spread) ที่กว้างขึ้น"),
        @("ตลาดหมี", "ตลาดขาลง (Bear Market)"),
        @("ตลาดกระทิง", "ตลาดขาขึ้น (Bull Market)"),
        @("ดิ่งลง", "ร่วงลงแรง"),
        @("ห้องปฏิบัติการจรวด", "Rocket Lab")
    )

    foreach ($r in $replacements) {
        $res = [regex]::Replace($res, $r[0], $r[1], [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    $res = [regex]::Replace($res, "\s+", " ").Trim()
    return $res
}

function Translate-ToThai($text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    $protected = Protect-Entities $text.Trim()
    try {
        $encoded = [System.Uri]::EscapeDataString($protected)
        $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=th&dt=t&q=$encoded"
        $res = Invoke-RestMethod -Uri $url -TimeoutSec 6 -Headers $headers
        $translated = ($res[0] | ForEach-Object { $_[0] }) -join ""
        if (-not [string]::IsNullOrWhiteSpace($translated)) {
            return Polish-ThaiFinancialText $translated.Trim()
        }
    } catch {}
    return Polish-ThaiFinancialText $protected
}

function Detect-Sentiment($text) {
    $upper = $text.ToUpper()
    $bullishWords = @(
        "SURGE", "JUMP", "GAIN", "RISE", "RALLY", "RECORD", "HIGH", "BEAT",
        "BOOST", "UPGRADE", "PROFIT", "GROWTH", "SOAR", "STRONG", "BULL",
        "OUTPERFORM", "CLIMB", "UPSIDE", "REBOUND", "TRIPLE", "EXPAND"
    )
    $bearishWords = @(
        "PLUNGE", "DROP", "FALL", "SLUMP", "TUMBLE", "MISS", "DOWNGRADE",
        "LOSS", "DECLINE", "SINK", "WARN", "BEAR", "RISK", "RECESSION",
        "CRASH", "DOWN", "SELLOFF", "PRESSURE", "TURMOIL", "PULLS"
    )
    $bullCount = 0
    foreach ($w in $bullishWords) {
        if ([regex]::IsMatch($upper, "\b" + [regex]::Escape($w) + "\b")) { $bullCount++ }
    }
    $bearCount = 0
    foreach ($w in $bearishWords) {
        if ([regex]::IsMatch($upper, "\b" + [regex]::Escape($w) + "\b")) { $bearCount++ }
    }
    if ($bullCount -gt $bearCount) { return "BULLISH" }
    elseif ($bearCount -gt $bullCount) { return "BEARISH" }
    return "NEUTRAL"
}

function Detect-Category($text, $defaultCat) {
    $upper = $text.ToUpper()
    if ([regex]::IsMatch($upper, "\b(AI|CHIP|CHIPS|SEMICONDUCTOR|SEMICONDUCTORS|SOFTWARE|CLOUD|NVIDIA|APPLE|MICROSOFT|TECH|TECHNOLOGY|BIG TECH|ALPHABET|GOOGLE|TPU|ROBOTIC|ROBOTICS|CYBERSECURITY|SAAS|STARLINK|SATELLITE|SPACE)\b")) {
        return "TECH"
    }
    if ([regex]::IsMatch($upper, "\b(EARNING|EARNINGS|REVENUE|PROFIT|PROFITS|QUARTER|RESULTS|Q1|Q2|Q3|Q4|GUIDANCE|EPS|FINANCIAL RESULTS|ORDERS)\b")) {
        return "EARNINGS"
    }
    if ([regex]::IsMatch($upper, "\b(OIL|CRUDE|OPEC|COMMODITY|COMMODITIES|GOLD|SILVER|NATURAL GAS|GASOLINE|BRENT|WTI|METALS|COPPER)\b")) {
        return "COMMODITIES"
    }
    if ([regex]::IsMatch($upper, "\b(FED|FEDERAL RESERVE|POWELL|INFLATION|CPI|PPI|INTEREST RATE|RATE CUT|RATE HIKE|TREASURY|BONDS?|YIELD|ECONOMY|ECONOMIC|RECESSION|JOBS|UNEMPLOYMENT|GDP|CENTRAL BANK|APPROVAL RATING|TRUMP|ELECTION|MIDTERM)\b")) {
        return "MACRO"
    }
    if ($defaultCat -and $defaultCat -ne "ALL") { return $defaultCat }
    return "MACRO"
}

function Detect-Tickers($text) {
    $upper = $text.ToUpper()
    $detected = [System.Collections.Generic.List[string]]::new()
    foreach ($sym in $tickerMap.Keys) {
        foreach ($k in $tickerMap[$sym]) {
            if ([regex]::IsMatch($upper, "(?:\b|\#)" + [regex]::Escape($k) + "\b")) {
                if (-not $detected.Contains($sym)) { $detected.Add($sym) }
                break
            }
        }
    }
    return $detected
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

# Fetch CNBC
$articles = [System.Collections.Generic.List[PSCustomObject]]::new()
$cnbcFeeds = @{
    "MACRO" = "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=10000664"
    "TECH" = "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=19854910"
    "ECONOMY" = "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=20910258"
    "EARNINGS" = "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=15839135"
}

foreach ($catKey in $cnbcFeeds.Keys) {
    $cat = if ($catKey -eq "ECONOMY") { "MACRO" } else { $catKey }
    try {
        $xml = Invoke-RestMethod -Uri $cnbcFeeds[$catKey] -TimeoutSec 8 -Headers $headers
        $count = 0
        foreach ($it in $xml.rss.channel.item) {
            if ($count -ge 6) { break }
            $title = $it.title.Trim()
            $link = $it.link.Trim()
            $desc = if ($it.description) { [regex]::Replace($it.description, "<[^>]+>", "").Trim() } else { $title }
            $pubDate = [DateTime]::UtcNow
            if ($it.pubDate) {
                try { $pubDate = [DateTime]::Parse($it.pubDate).ToUniversalTime() } catch {}
            }
            if ($title -and $link) {
                $articles.Add([PSCustomObject]@{
                    title = $title
                    summary = if ($desc) { $desc } else { $title }
                    source = "CNBC"
                    sourceUrl = $link
                    publishedAt = $pubDate
                    defaultCat = $cat
                })
                $count++
            }
        }
    } catch {
        Write-Host "Warning: Could not fetch CNBC $catKey"
    }
}

# Fetch Yahoo News
$yahooQueries = @("stock market", "Federal Reserve interest rate", "artificial intelligence tech", "crude oil")
foreach ($q in $yahooQueries) {
    try {
        $url = "https://query2.finance.yahoo.com/v1/finance/search?q=" + [System.Uri]::EscapeDataString($q) + "&newsCount=5"
        $raw = Invoke-RestMethod -Uri $url -TimeoutSec 8 -Headers $headers
        if ($raw.news) {
            foreach ($n in $raw.news) {
                $title = if ($n.title) { $n.title.Trim() } else { "" }
                $link = if ($n.link) { $n.link.Trim() } else { "" }
                $publisher = if ($n.publisher) { $n.publisher.Trim() } else { "Yahoo Finance" }
                $snippet = if ($n.snippet) { $n.snippet.Trim() } elseif ($n.summary) { $n.summary.Trim() } else { $title }
                $pubDate = [DateTime]::UtcNow
                if ($n.providerPublishTime) {
                    try {
                        $dto = [DateTimeOffset]::FromUnixTimeSeconds([long]$n.providerPublishTime)
                        $pubDate = $dto.UtcDateTime
                    } catch {}
                }
                if ($title -and $link) {
                    $articles.Add([PSCustomObject]@{
                        title = $title
                        summary = $snippet
                        source = $publisher
                        sourceUrl = $link
                        publishedAt = $pubDate
                        defaultCat = "ALL"
                    })
                }
            }
        }
    } catch {
        Write-Host "Warning: Yahoo Finance query $q failed"
    }
}

Write-Host "Total raw articles: $($articles.Count)"

# Deduplicate
$seen = [System.Collections.Generic.HashSet[string]]::new()
$unique = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($art in $articles) {
    $normUrl = $art.sourceUrl.Split("?")[0].ToLower()
    $normTitle = $art.title.ToLower()
    if (-not $seen.Contains($normUrl) -and -not $seen.Contains($normTitle)) {
        $seen.Add($normUrl) | Out-Null
        $seen.Add($normTitle) | Out-Null
        $unique.Add($art)
    }
}

# Safety guard: if unable to fetch articles, do not wipe out news.json
if ($unique.Count -lt 3) {
    Write-Host "Warning: Only $($unique.Count) articles retrieved. Keeping existing data/news.json to prevent data loss."
    return
}

# Sort descending by publishedAt
$sorted = $unique | Sort-Object -Property publishedAt -Descending
$top12 = $sorted | Select-Object -First 12

$nowUtc = [DateTimeOffset]::UtcNow
$processedNews = [System.Collections.Generic.List[PSCustomObject]]::new()
$idCounter = 1

Write-Host "Processing top $($top12.Count) articles..."

foreach ($item in $top12) {
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

    $tickerTagStr = ($tickers | ForEach-Object { "#" + $_ }) -join " "

    # Market perspective based on category and sentiment
    $marketPerspective = switch ($category) {
        "TECH" {
            if ($sentiment -eq "BULLISH") { "สะท้อนความต้องการและการลงทุนในกลุ่ม AI และโครงสร้างพื้นฐานคลาวด์ที่ยังเติบโตต่อเนื่อง หนุนความเชื่อมั่นนักลงทุน" }
            elseif ($sentiment -eq "BEARISH") { "สะท้อนแรงกดดันด้านต้นทุน การแข่งขัน หรือความเสี่ยงด้านเครดิตในกลุ่มเทคโนโลยีที่นักลงทุนควรติดตามอย่างระมัดระวัง" }
            else { "ความคืบหน้าของอุตสาหกรรมเทคโนโลยีที่ส่งผลต่อโมเมนตัมของตลาดและการแข่งขันในระดับสากล" }
        }
        "MACRO" {
            if ($sentiment -eq "BULLISH") { "ช่วยผ่อนคลายความกังวลด้านเศรษฐกิจมหภาค และหนุนกระแสเงินทุนไหลกลับเข้าสู่สินทรัพย์เสี่ยง" }
            elseif ($sentiment -eq "BEARISH") { "เพิ่มความกังวลด้านแรงกดดันเงินเฟ้อและทิศทางอัตราดอกเบี้ย ส่งผลให้ตลาดอาจเผชิญความผันผวนระยะสั้น" }
            else { "สะท้อนความไม่แน่นอนของปัจจัยเศรษฐกิจและนโยบายการเงินที่ตลาดยังคงรอดูความชัดเจนเพื่อประเมินทิศทางต่อไป" }
        }
        "COMMODITIES" {
            if ($sentiment -eq "BULLISH") { "ราคาสินค้าโภคภัณฑ์ปรับตัวขึ้นจากความตึงเครียดทางภูมิรัฐศาสตร์และอุปทานตึงตัว หนุนหุ้นกลุ่มพลังงาน" }
            elseif ($sentiment -eq "BEARISH") { "ความต้องการชะลอตัวหรืออุปทานส่วนเกินอาจกดดันราคาสินค้าโภคภัณฑ์และอัตรากำไรของกลุ่มผู้ผลิต" }
            else { "ความผันผวนของราคาสินค้าโภคภัณฑ์ยังคงขึ้นอยู่กับประเด็นภูมิรัฐศาสตร์และนโยบายการผลิตระดับโลก" }
        }
        "EARNINGS" {
            if ($sentiment -eq "BULLISH") { "ผลการดำเนินงานหรือยอดคำสั่งซื้อเติบโตโดดเด่น หนุนมุมมองเชิงบวกของนักวิเคราะห์ต่อแนวโน้มกำไร" }
            elseif ($sentiment -eq "BEARISH") { "ผลประกอบการหรือยอดขายที่ชะลอตัวลง ส่งผลให้เกิดแรงขายทำกำไรและปรับลดประมาณการกำไร" }
            else { "ตลาดกำลังจับตารายละเอียดงบการเงินและคาดการณ์ผลการดำเนินงานในไตรมาสถัดไป" }
        }
        Default { "ประเด็นสำคัญที่ส่งผลต่อการปรับสมดุลพอร์ตลงทุนและบรรยากาศการซื้อขายในตลาด" }
    }

    $coreSummary = if ($thSummary -and $thSummary -ne $thTitle) { $thSummary } else { $thTitle }

    $points = @(
        "📌 สาระสำคัญ: $coreSummary",
        "📊 นัยสำคัญต่อตลาด: $marketPerspective",
        "🎯 หุ้นที่น่าจับตา: ติดตามความเคลื่อนไหวของกลุ่มหุ้นที่เกี่ยวข้อง $tickerTagStr ซึ่งอาจมีความผันผวนตามประเด็นข่าวนี้"
    )

    $catThai = switch ($category) {
        "TECH" { "เทคโนโลยีและปัญญาประดิษฐ์ (AI)" }
        "MACRO" { "เศรษฐกิจมหภาคและนโยบายการเงิน" }
        "COMMODITIES" { "พลังงานและสินค้าโภคภัณฑ์" }
        "EARNINGS" { "ผลการดำเนินงานและผลประกอบการบริษัทจดทะเบียน" }
        Default { "ตลาดทุนและเศรษฐกิจสากล" }
    }

    $p1 = if ($thSummary -and $thSummary -ne $thTitle) {
        "$thTitle โดยมีรายงานว่า $thSummary"
    } else {
        "$thTitle ซึ่งเป็นหนึ่งในประเด็นสำคัญที่ตลาดการเงินและนักลงทุนทั่วโลกกำลังให้ความสนใจอย่างใกล้ชิดในรอบวัน"
    }

    $p2 = "รายงานจาก $($item.source) ระบุว่า ความเคลื่อนไหวดังกล่าวส่งผลต่อมุมมองของนักลงทุนสถาบันและผู้เล่นในตลาด โดยเฉพาะในกลุ่มอุตสาหกรรม$catThai ซึ่งกำลังเผชิญกับปัจจัยขับเคลื่อนทั้งด้านแนวโน้มอุปสงค์-อุปทาน และการปรับสมดุลพอร์ตการลงทุนเพื่อรับมือกับความเปลี่ยนแปลงของสภาวะเศรษฐกิจโลก"

    $p3 = "ในมุมมองการลงทุนระยะสั้นถึงระยะกลาง นักวิเคราะห์ประเมินว่าหุ้นกลุ่มที่ได้รับผลกระทบอย่าง $tickerTagStr อาจเผชิญความผันผวนของราคาตามทิศทางกระแสข่าว โดยนักลงทุนควรติดตามข้อมูลความคืบหน้าอย่างใกล้ชิดควบคู่กับการประเมินแนวรับแนวต้านทางเทคนิค (อ้างอิงรายงานภาษาอังกฤษ: `"$($item.title)`")"

    $fullArticle = @($p1, $p2, $p3)

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
