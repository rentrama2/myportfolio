#!/usr/bin/env python3
"""
scripts/update_news.py
Fetches live financial and market news from CNBC and Yahoo Finance.
Categorizes, analyzes sentiment, extracts tickers, translates to Thai,
and outputs structured data to data/news.json.
"""
import os
import json
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
import datetime
import html
import re

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

TICKER_MAP = {
    "NVDA": ["NVIDIA", "NVDA", "BLACKWELL", "GEFORCE", "JENSEN HUANG"],
    "AAPL": ["APPLE", "AAPL", "IPHONE", "TIM COOK", "IOS"],
    "MSFT": ["MICROSOFT", "MSFT", "AZURE", "SATYA NADELLA", "WINDOWS"],
    "GOOGL": ["GOOGLE", "ALPHABET", "GOOGL", "GOOG", "GEMINI", "YOUTUBE"],
    "AMZN": ["AMAZON", "AMZN", "AWS", "BEZOS"],
    "META": ["META", "FACEBOOK", "ZUCKERBERG", "INSTAGRAM"],
    "TSLA": ["TESLA", "TSLA", "ELON MUSK", "CYBERTRUCK", "CYBERCAB", "ROBOVAN"],
    "AMD": ["AMD", "ADVANCED MICRO DEVICES", "LISA SU"],
    "INTC": ["INTEL", "INTC", "GELSINGER"],
    "TSM": ["TSMC", "TSM", "TAIWAN SEMICONDUCTOR"],
    "SPY": ["S&P 500", "SPY", "SP500"],
    "QQQ": ["NASDAQ", "QQQ", "TECH STOCKS"],
    "DIA": ["DOW JONES", "DIA", "DOW"],
    "TLT": ["TREASURY", "BONDS", "10-YEAR", "BOND YIELD", "TLT"],
    "JPM": ["JPMORGAN", "JPM", "JAMIE DIMON"],
    "GS": ["GOLDMAN SACHS", "GS"],
    "BAC": ["BANK OF AMERICA", "BAC"],
    "WFC": ["WELLS FARGO", "WFC"],
    "XOM": ["EXXON", "EXXONMOBIL", "XOM"],
    "CVX": ["CHEVRON", "CVX"],
    "LLY": ["ELI LILLY", "LLY", "MOUNJARO", "ZEPBOUND"],
    "NVO": ["NOVO NORDISK", "NVO", "OZEMPIC", "WEGOVY"],
    "CRM": ["SALESFORCE", "CRM"],
    "NFLX": ["NETFLIX", "NFLX"],
    "COIN": ["COINBASE", "COIN", "BITCOIN", "CRYPTO"],
    "PLTR": ["PALANTIR", "PLTR"],
    "SCHD": ["SCHD", "DIVIDEND"],
    "VOO": ["VOO"],
    "VTI": ["VTI"]
}

def clean_html(raw_html):
    if not raw_html:
        return ""
    clean = re.sub(r"<[^>]+>", "", raw_html)
    return html.unescape(clean).strip()

def translate_to_thai(text):
    if not text or not text.strip():
        return ""
    try:
        q = urllib.parse.quote(text.strip())
        url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=th&dt=t&q={q}"
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data and isinstance(data, list) and len(data) > 0 and isinstance(data[0], list):
                translated = "".join(part[0] for part in data[0] if part and part[0])
                if translated.strip():
                    return translated.strip()
    except Exception:
        pass
    return text.strip()

def detect_sentiment(text):
    upper = text.upper()
    bullish_words = [
        "SURGE", "JUMP", "GAIN", "RISE", "RALLY", "RECORD", "HIGH", "BEAT",
        "BOOST", "UPGRADE", "PROFIT", "GROWTH", "SOAR", "STRONG", "BULL",
        "OUTPERFORM", "CLIMB", "UPSIDE", "REBOUND"
    ]
    bearish_words = [
        "PLUNGE", "DROP", "FALL", "SLUMP", "TUMBLE", "MISS", "DOWNGRADE",
        "LOSS", "DECLINE", "SINK", "WARN", "BEAR", "RISK", "RECESSION",
        "CRASH", "DOWN", "SELLOFF", "PRESSURE"
    ]
    bull_count = sum(1 for w in bullish_words if w in upper)
    bear_count = sum(1 for w in bearish_words if w in upper)
    if bull_count > bear_count:
        return "BULLISH"
    elif bear_count > bull_count:
        return "BEARISH"
    return "NEUTRAL"

def detect_category(text, default_cat="ALL"):
    upper = text.upper()
    if any(w in upper for w in ["OIL", "CRUDE", "OPEC", "COMMODIT", "GOLD", "GAS"]):
        return "COMMODITIES"
    if any(w in upper for w in ["EARNING", "REVENUE", "PROFIT", "QUARTER", "RESULTS", "Q3", "Q4", "GUIDANCE"]):
        return "EARNINGS"
    if any(w in upper for w in ["FED", "POWELL", "INFLATION", "CPI", "INTEREST RATE", "RATE CUT", "TREASURY", "ECONOMY", "JOBS"]):
        return "MACRO"
    if any(w in upper for w in ["AI", "CHIP", "TECH", "SEMICONDUCTOR", "SOFTWARE", "CLOUD", "NVIDIA", "APPLE", "MICROSOFT"]):
        return "TECH"
    return default_cat if default_cat != "ALL" else "MACRO"

def detect_tickers(text, category):
    upper = text.upper()
    detected = []
    for sym, keywords in TICKER_MAP.items():
        for k in keywords:
            pattern = r"(?:\b|\#)" + re.escape(k) + r"\b"
            if re.search(pattern, upper):
                if sym not in detected:
                    detected.append(sym)
                break
    if not detected:
        if category == "MACRO":
            detected = ["SPY", "QQQ", "TLT"]
        elif category == "TECH":
            detected = ["NVDA", "AAPL", "MSFT"]
        elif category == "COMMODITIES":
            detected = ["XOM", "CVX"]
        elif category == "EARNINGS":
            detected = ["SPY", "DIA"]
        else:
            detected = ["SPY"]
    return detected

def format_relative_time_thai(diff_seconds):
    if diff_seconds < 60:
        return "เมื่อสักครู่"
    mins = int(diff_seconds // 60)
    if mins < 60:
        return f"{mins} นาทีที่แล้ว"
    hours = int(mins // 60)
    if hours < 24:
        return f"{hours} ชั่วโมงที่แล้ว"
    days = int(hours // 24)
    return f"{days} วันที่แล้ว"

def fetch_cnbc_feeds():
    feeds = {
        "MACRO": "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=10000664",
        "TECH": "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=19854910",
        "ECONOMY": "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=20910258",
        "EARNINGS": "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=15839135",
    }
    articles = []
    for cat_key, url in feeds.items():
        cat = "MACRO" if cat_key == "ECONOMY" else cat_key
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=8) as resp:
                xml_data = resp.read()
                root = ET.fromstring(xml_data)
                items = root.findall(".//item")
                for it in items[:6]:
                    title_elem = it.find("title")
                    link_elem = it.find("link")
                    pub_elem = it.find("pubDate")
                    desc_elem = it.find("description")

                    title = title_elem.text.strip() if title_elem is not None and title_elem.text else ""
                    link = link_elem.text.strip() if link_elem is not None and link_elem.text else ""
                    desc = clean_html(desc_elem.text) if desc_elem is not None and desc_elem.text else ""

                    if not title or not link:
                        continue

                    pub_dt = datetime.datetime.now(datetime.timezone.utc)
                    if pub_elem is not None and pub_elem.text:
                        try:
                            # e.g. Mon, 12 Oct 2026 12:20:13 GMT
                            pub_dt = datetime.datetime.strptime(pub_elem.text.strip(), "%a, %d %b %Y %H:%M:%S %Z")
                            pub_dt = pub_dt.replace(tzinfo=datetime.timezone.utc)
                        except Exception:
                            try:
                                from email.utils import parsedate_to_datetime
                                pub_dt = parsedate_to_datetime(pub_elem.text.strip())
                            except Exception:
                                pass

                    articles.append({
                        "title": title,
                        "summary": desc or title,
                        "source": "CNBC",
                        "sourceUrl": link,
                        "publishedAt": pub_dt,
                        "defaultCat": cat
                    })
        except Exception as e:
            print(f"Warning: CNBC {cat_key} failed: {e}")
    return articles

def fetch_yahoo_news():
    queries = ["stock market", "Federal Reserve interest rate", "artificial intelligence tech", "crude oil"]
    articles = []
    for q in queries:
        try:
            url = f"https://query2.finance.yahoo.com/v1/finance/search?q={urllib.parse.quote(q)}&newsCount=5"
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=8) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                for n in data.get("news", []):
                    title = n.get("title", "").strip()
                    link = n.get("link", "").strip()
                    publisher = n.get("publisher", "Yahoo Finance").strip() or "Yahoo Finance"
                    pub_time = n.get("providerPublishTime")

                    if not title or not link:
                        continue

                    pub_dt = datetime.datetime.now(datetime.timezone.utc)
                    if pub_time:
                        try:
                            pub_dt = datetime.datetime.fromtimestamp(pub_time, datetime.timezone.utc)
                        except Exception:
                            pass

                    articles.append({
                        "title": title,
                        "summary": title,
                        "source": publisher,
                        "sourceUrl": link,
                        "publishedAt": pub_dt,
                        "defaultCat": "ALL"
                    })
        except Exception as e:
            print(f"Warning: Yahoo query {q} failed: {e}")
    return articles

def main():
    repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    news_file = os.path.join(repo_dir, "data", "news.json")
    print(f"Updating Live Market News: {news_file}")

    all_articles = []
    all_articles.extend(fetch_cnbc_feeds())
    all_articles.extend(fetch_yahoo_news())
    print(f"Collected total {len(all_articles)} raw articles.")

    # Deduplicate by normalized URL or title
    seen = set()
    unique_articles = []
    for art in all_articles:
        norm_key = art["sourceUrl"].split("?")[0].lower()
        title_key = art["title"].lower()
        if norm_key not in seen and title_key not in seen:
            seen.add(norm_key)
            seen.add(title_key)
            unique_articles.append(art)

    # Sort descending by publishedAt
    unique_articles.sort(key=lambda x: x["publishedAt"], reverse=True)

    # Select top 12 curated news
    selected = unique_articles[:12]
    now_utc = datetime.datetime.now(datetime.timezone.utc)

    processed_news = []
    for idx, item in enumerate(selected, 1):
        diff_sec = max(0, (now_utc - item["publishedAt"]).total_seconds())
        time_thai = format_relative_time_thai(diff_sec)

        title_en = item["title"]
        summary_en = item["summary"]

        print(f"[{idx}] Translating: {title_en[:50]}...")
        th_title = translate_to_thai(title_en)
        th_summary = translate_to_thai(summary_en) if summary_en != title_en else th_title

        combined_en = f"{title_en} {summary_en}"
        category = detect_category(combined_en, item["defaultCat"])
        tickers = detect_tickers(combined_en, category)
        sentiment = detect_sentiment(combined_en)

        impact_map = {
            "BULLISH": "เชิงบวกต่อบรรยากาศการลงทุนและสินทรัพย์เสี่ยง",
            "BEARISH": "ปัจจัยความเสี่ยงที่ต้องติดตามความผันผวน",
            "NEUTRAL": "เกาะติดความคืบหน้าและประเมินทิศทางตลาด"
        }
        impact = impact_map.get(sentiment, "เกาะติดสถานการณ์ตลาด")

        points = [
            th_summary,
            f"แหล่งข่าวอ้างอิง: {item['source']} ({item['publishedAt'].strftime('%d/%m/%Y %H:%M')} UTC)",
            f"กลุ่มสินทรัพย์และหุ้นที่เกี่ยวข้อง: {' '.join('#' + t for t in tickers)}"
        ]

        full_article = [
            th_title,
            th_summary,
            f"รายงานต้นฉบับภาษาอังกฤษระบุว่า: \"{title_en}\" ซึ่งนักวิเคราะห์ในตลาดกำลังจับตาดูผลกระทบต่อทิศทางราคาและผลตอบแทนในระยะสั้นถึงระยะกลาง"
        ]

        processed_news.append({
            "id": f"news-{idx}",
            "title": th_title,
            "title_en": title_en,
            "summary": th_summary,
            "source": item["source"],
            "sourceUrl": item["sourceUrl"],
            "time": time_thai,
            "publishedAt": item["publishedAt"].strftime("%Y-%m-%dT%H:%M:%SZ"),
            "category": category,
            "tickers": tickers,
            "sentiment": sentiment,
            "impact": impact,
            "isHero": (idx == 1),
            "points": points,
            "fullArticle": full_article
        })

    thai_tz = datetime.timezone(datetime.timedelta(hours=7))
    now_thai = now_utc.astimezone(thai_tz)
    thai_months = ["", "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
    thai_str = f"{now_thai.day} {thai_months[now_thai.month]} {now_thai.year + 543} {now_thai.strftime('%H:%M')} น."

    output = {
        "updated_at": now_utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "updated_at_thai": thai_str,
        "news_count": len(processed_news),
        "news": processed_news
    }

    os.makedirs(os.path.dirname(news_file), exist_ok=True)
    with open(news_file, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"Successfully wrote {len(processed_news)} live news to {news_file} at {thai_str}")

if __name__ == "__main__":
    main()
