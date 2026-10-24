#!/usr/bin/env python3
"""
scripts/update_news.py
Fetches live financial and market news from CNBC and Yahoo Finance.
Categorizes, analyzes sentiment, extracts tickers, applies financial entity protection,
translates to high-quality Thai, and synthesizes 3-point key takeaways and
3-paragraph in-depth analysis for data/news.json.
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

# Proper nouns and financial terms to protect before translation
PROTECT_TERMS = [
    ("Credit Default Swaps", "__ENT_CDS__"),
    ("Credit default swaps", "__ENT_CDS__"),
    ("credit default swaps", "__ENT_CDS__"),
    ("Free Cash Flow", "__ENT_FCF__"),
    ("free cash flow", "__ENT_FCF__"),
    ("Rocket Lab", "__ENT_ROCKETLAB__"),
    ("Simply Wall St.", "__ENT_SIMPLYWALLST__"),
    ("Stocktwits", "__ENT_STOCKTWITS__"),
    ("Solidigm", "__ENT_SOLIDIGM__"),
    ("Alphabet", "__ENT_ALPHABET__"),
    ("Google", "__ENT_GOOGLE__"),
    ("Starlink", "__ENT_STARLINK__"),
    ("Starshield", "__ENT_STARSHIELD__"),
    ("SpaceX", "__ENT_SPACEX__"),
    ("Nokia", "__ENT_NOKIA__"),
    ("ICEYE", "__ENT_ICEYE__"),
    ("Volvo Cars", "__ENT_VOLVOCARS__"),
    ("Volvo", "__ENT_VOLVO__"),
    ("Saab", "__ENT_SAAB__"),
    ("Gripen", "__ENT_GRIPEN__"),
    ("iPhone Duo", "__ENT_IPHONEDUO__"),
    ("iPhone", "__ENT_IPHONE__"),
    ("S&P 500", "__ENT_SP500__"),
    ("Dow Jones", "__ENT_DOWJONES__"),
    ("Nasdaq", "__ENT_NASDAQ__"),
    ("Russell 2000", "__ENT_RUSSELL2000__"),
    ("Federal Reserve", "__ENT_FED__"),
    ("Fed", "__ENT_FED__"),
    ("Jerome Powell", "__ENT_POWELL__"),
    ("Powell", "__ENT_POWELL__"),
    ("Donald Trump", "__ENT_TRUMP__"),
    ("Trump", "__ENT_TRUMP__"),
    ("Elon Musk", "__ENT_ELONMUSK__"),
    ("Musk", "__ENT_MUSK__"),
    ("Tim Cook", "__ENT_TIMCOOK__"),
    ("Jensen Huang", "__ENT_JENSENHUANG__"),
    ("Satya Nadella", "__ENT_SATYANADELLA__"),
    ("TPU", "__ENT_TPU__"),
    ("IPO", "__ENT_IPO__"),
    ("CDS", "__ENT_CDS__"),
    ("FCF", "__ENT_FCF__"),
    ("Scalpers", "__ENT_SCALPERS__"),
    ("scalpers", "__ENT_SCALPERS__"),
    ("Neoclouds", "__ENT_NEOCLOUDS__"),
    ("neoclouds", "__ENT_NEOCLOUDS__"),
    ("Neocloud", "__ENT_NEOCLOUDS__"),
    ("neocloud", "__ENT_NEOCLOUDS__"),
    ("Hyperscalers", "__ENT_HYPERSCALERS__"),
    ("hyperscalers", "__ENT_HYPERSCALERS__"),
    ("Hyperscaler", "__ENT_HYPERSCALERS__"),
    ("hyperscaler", "__ENT_HYPERSCALERS__"),
    ("Midterms", "__ENT_MIDTERMS__"),
    ("midterms", "__ENT_MIDTERMS__"),
    ("Midterm", "__ENT_MIDTERMS__"),
    ("midterm", "__ENT_MIDTERMS__")
]

# Sort terms by length descending to ensure multi-word entities match first
PROTECT_TERMS_SORTED = sorted(PROTECT_TERMS, key=lambda x: len(x[0]), reverse=True)

RESTORE_MAP = {
    "__ENT_ALPHABET__": "Alphabet",
    "__ENT_GOOGLE__": "Google",
    "__ENT_ROCKETLAB__": "Rocket Lab",
    "__ENT_SIMPLYWALLST__": "Simply Wall St.",
    "__ENT_STOCKTWITS__": "Stocktwits",
    "__ENT_SOLIDIGM__": "Solidigm",
    "__ENT_STARLINK__": "Starlink",
    "__ENT_STARSHIELD__": "Starshield",
    "__ENT_SPACEX__": "SpaceX",
    "__ENT_NOKIA__": "Nokia",
    "__ENT_ICEYE__": "ICEYE",
    "__ENT_VOLVOCARS__": "Volvo Cars",
    "__ENT_VOLVO__": "Volvo",
    "__ENT_SAAB__": "Saab",
    "__ENT_GRIPEN__": "เครื่องบินขับไล่ Gripen",
    "__ENT_IPHONEDUO__": "Apple iPhone Duo",
    "__ENT_IPHONE__": "iPhone",
    "__ENT_SP500__": "S&P 500",
    "__ENT_DOWJONES__": "Dow Jones",
    "__ENT_NASDAQ__": "Nasdaq",
    "__ENT_RUSSELL2000__": "Russell 2000",
    "__ENT_FED__": "เฟด (Fed)",
    "__ENT_POWELL__": "พาวเวลล์ (Powell)",
    "__ENT_TRUMP__": "ทรัมป์ (Trump)",
    "__ENT_ELONMUSK__": "อีลอน มัสก์ (Elon Musk)",
    "__ENT_MUSK__": "มัสก์ (Musk)",
    "__ENT_TIMCOOK__": "ทิม คุก (Tim Cook)",
    "__ENT_JENSENHUANG__": "เจนเซ่น หวง (Jensen Huang)",
    "__ENT_SATYANADELLA__": "สัตยา นาเดลลา (Satya Nadella)",
    "__ENT_CDS__": "สัญญาประกันหนี้เสีย (CDS)",
    "__ENT_TPU__": "ชิป TPU",
    "__ENT_IPO__": "IPO",
    "__ENT_FCF__": "กระแสเงินสดอิสระ (Free Cash Flow)",
    "__ENT_SCALPERS__": "กลุ่มพ่อค้าเก็งกำไร (Scalpers)",
    "__ENT_NEOCLOUDS__": "กลุ่ม Neoclouds",
    "__ENT_HYPERSCALERS__": "กลุ่มผู้ให้บริการคลาวด์ยักษ์ใหญ่ (Hyperscalers)",
    "__ENT_MIDTERMS__": "การเลือกตั้งกลางเทอม (Midterms)"
}

def protect_entities(text):
    if not text:
        return ""
    protected = text
    for term, token in PROTECT_TERMS_SORTED:
        pattern = r"\b" + re.escape(term) + r"\b"
        protected = re.sub(pattern, token, protected)
    return protected

def polish_thai_financial_text(text):
    if not text:
        return ""

    # Restore placeholders first
    for token, replacement in RESTORE_MAP.items():
        text = text.replace(token, replacement)
        # Handle cases where machine translation adds spaces inside placeholder
        spaced_token = token.replace("_", r"\s*_\s*")
        text = re.sub(spaced_token, replacement, text, flags=re.IGNORECASE)

    # Clean up literal machine translation artifacts
    replacements = [
        (r"\bตัวอักษร\s*\((?:GOOGL|GOOG)\)", "Alphabet (GOOGL)"),
        (r"ตัวอักษร\s*\(\s*GOOGL\s*\)", "Alphabet (GOOGL)"),
        (r"ผู้ถลกหนัง", "กลุ่มพ่อค้าเก็งกำไร (Scalpers)"),
        (r"สัญญาแลกเปลี่ยนเครดิตเริ่มต้น", "สัญญาประกันการผิดนัดชำระหนี้ (Credit Default Swaps / CDS)"),
        (r"การดึง\s*IPO", "การระงับแผนเข้าตลาดหุ้น IPO"),
        (r"ดึง\s*IPO", "ถอนการยื่นเสนอขายหุ้น IPO"),
        (r"การบรรยายสรุป", "สรุปภาพรวม"),
        (r"ตัวขับเคลื่อนตลาด", "ปัจจัยขับเคลื่อนตลาด"),
        (r"ทำให้เกิดความกลัวต่อ", "สร้างความกังวลต่อ"),
        (r"ทำให้เกิดความกลัว", "จุดชนวนความกังวล"),
        (r"การสร้าง\s*AI", "การขยายโครงสร้างพื้นฐาน AI (AI Build-out)"),
        (r"เบื้องหลังความต้องการ", "เพื่อรองรับอุปสงค์"),
        (r"เมื่อถึงกลางภาค", "ก่อนการเลือกตั้งกลางเทอม (Midterms)"),
        (r"คะแนนการอนุมัติ", "คะแนนความนิยม (Approval Rating)"),
        (r"ยุติธรรมหรือยากจน", "ปานกลางถึงย่ำแย่"),
        (r"ในการตามล่าหา", "ในการมองหาทางเลือกทดแทน"),
        (r"ส่งผลเสียต่อกระแสเงินสดอิสระ", "กดดันกระแสเงินสดอิสระ (Free Cash Flow)"),
        (r"ไฮเปอร์สเกลเลอร์", "ผู้ให้บริการคลาวด์ยักษ์ใหญ่ (Hyperscalers)"),
        (r"นีโอคลาวด์", "กลุ่มผู้ให้บริการคลาวด์รุ่นใหม่ (Neoclouds)"),
        (r"การตกต่ำของหุ้น", "การปรับตัวลงของราคาหุ้น"),
        (r"สเปรดที่เพิ่มขึ้น", "ส่วนต่างอัตราผลตอบแทน (Credit Spread) ที่กว้างขึ้น"),
        (r"ตลาดหมี", "ตลาดขาลง (Bear Market)"),
        (r"ตลาดกระทิง", "ตลาดขาขึ้น (Bull Market)"),
        (r"ปรับลดอัตราดอกเบี้ย", "การปรับลดอัตราดอกเบี้ย"),
        (r"ปรับขึ้นอัตราดอกเบี้ย", "การปรับขึ้นอัตราดอกเบี้ย"),
        (r"ดิ่งลง", "ร่วงลงแรง"),
        (r"การต่อสู้ที่ยากลำบาก", "ศึกหนักในการแข่งขัน"),
        (r"เห็นคำสั่งซื้อเพิ่มขึ้นสามเท่า", "กวาดยอดคำสั่งซื้อเพิ่มขึ้นทะลัก 3 เท่า"),
        (r"ห้องปฏิบัติการจรวด", "Rocket Lab")
    ]

    for pattern, repl in replacements:
        text = re.sub(pattern, repl, text, flags=re.IGNORECASE)

    # Normalize excessive spaces
    text = re.sub(r"\s+", " ", text).strip()
    return text

def clean_html(raw_html):
    if not raw_html:
        return ""
    clean = re.sub(r"<[^>]+>", "", raw_html)
    return html.unescape(clean).strip()

def translate_to_thai(text):
    if not text or not text.strip():
        return ""

    protected_text = protect_entities(text.strip())
    q = urllib.parse.quote(protected_text)
    endpoints = [
        f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=th&dt=t&q={q}",
        f"https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=en&tl=th&q={q}",
        f"https://api.mymemory.translated.net/get?q={q}&langpair=en|th"
    ]

    translated_raw = None
    for url in endpoints:
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=6) as resp:
                raw = resp.read().decode("utf-8")
                try:
                    data = json.loads(raw)
                    if isinstance(data, list) and len(data) > 0 and isinstance(data[0], list):
                        translated = "".join(part[0] for part in data[0] if part and part[0])
                        if translated.strip():
                            translated_raw = translated.strip()
                            break
                    elif isinstance(data, list) and len(data) > 0 and isinstance(data[0], str):
                        if data[0].strip():
                            translated_raw = data[0].strip()
                            break
                    elif isinstance(data, dict) and "responseData" in data:
                        res_text = data.get("responseData", {}).get("translatedText", "")
                        if res_text and not res_text.startswith("MYMEMORY WARNING"):
                            translated_raw = res_text.strip()
                            break
                except Exception:
                    pass
        except Exception:
            continue

    if not translated_raw:
        translated_raw = protected_text

    return polish_thai_financial_text(translated_raw)

def detect_sentiment(text):
    upper = text.upper()
    bullish_words = [
        "SURGE", "JUMP", "GAIN", "RISE", "RALLY", "RECORD", "HIGH", "BEAT",
        "BOOST", "UPGRADE", "PROFIT", "GROWTH", "SOAR", "STRONG", "BULL",
        "OUTPERFORM", "CLIMB", "UPSIDE", "REBOUND", "TRIPLE", "EXPAND"
    ]
    bearish_words = [
        "PLUNGE", "DROP", "FALL", "SLUMP", "TUMBLE", "MISS", "DOWNGRADE",
        "LOSS", "DECLINE", "SINK", "WARN", "BEAR", "RISK", "RECESSION",
        "CRASH", "DOWN", "SELLOFF", "PRESSURE", "TURMOIL", "PULLS"
    ]
    bull_count = sum(1 for w in bullish_words if re.search(r"\b" + re.escape(w) + r"\b", upper))
    bear_count = sum(1 for w in bearish_words if re.search(r"\b" + re.escape(w) + r"\b", upper))
    if bull_count > bear_count:
        return "BULLISH"
    elif bear_count > bull_count:
        return "BEARISH"
    return "NEUTRAL"

def detect_category(text, default_cat="ALL"):
    upper = text.upper()
    # Check Tech / AI with regex word boundaries
    if re.search(r"\b(AI|CHIP|CHIPS|SEMICONDUCTOR|SEMICONDUCTORS|SOFTWARE|CLOUD|NVIDIA|APPLE|MICROSOFT|TECH|TECHNOLOGY|BIG TECH|ALPHABET|GOOGLE|TPU|ROBOTIC|ROBOTICS|CYBERSECURITY|SAAS|STARLINK|SATELLITE|SPACE)\b", upper):
        return "TECH"
    # Check Earnings
    if re.search(r"\b(EARNING|EARNINGS|REVENUE|PROFIT|PROFITS|QUARTER|RESULTS|Q1|Q2|Q3|Q4|GUIDANCE|EPS|FINANCIAL RESULTS|ORDERS)\b", upper):
        return "EARNINGS"
    # Check Commodities with strict word boundaries to avoid matching TURMOIL -> OIL
    if re.search(r"\b(OIL|CRUDE|OPEC|COMMODITY|COMMODITIES|GOLD|SILVER|NATURAL GAS|GASOLINE|BRENT|WTI|METALS|COPPER)\b", upper):
        return "COMMODITIES"
    # Check Macro / Fed / Economy
    if re.search(r"\b(FED|FEDERAL RESERVE|POWELL|INFLATION|CPI|PPI|INTEREST RATE|RATE CUT|RATE HIKE|TREASURY|BONDS?|YIELD|ECONOMY|ECONOMIC|RECESSION|JOBS|UNEMPLOYMENT|GDP|CENTRAL BANK|APPROVAL RATING|TRUMP|ELECTION|MIDTERM)\b", upper):
        return "MACRO"
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

def generate_key_takeaways(item, category, sentiment, tickers, th_title, th_summary):
    """
    Generates 3 structured, non-repetitive Key Takeaways:
    1. Core event summary
    2. Market & sector analytical perspective
    3. Watchlist tickers & trading outlook
    """
    core_summary = th_summary if th_summary and th_summary != th_title else th_title

    # Analytical perspective based on category and sentiment
    if category == "TECH":
        if sentiment == "BULLISH":
            market_perspective = "สะท้อนความต้องการและการลงทุนในกลุ่ม AI และโครงสร้างพื้นฐานคลาวด์ที่ยังเติบโตต่อเนื่อง หนุนความเชื่อมั่นนักลงทุน"
        elif sentiment == "BEARISH":
            market_perspective = "สะท้อนแรงกดดันด้านต้นทุน การแข่งขัน หรือความเสี่ยงด้านเครดิตในกลุ่มเทคโนโลยีที่นักลงทุนควรติดตามอย่างระมัดระวัง"
        else:
            market_perspective = "ความคืบหน้าของอุตสาหกรรมเทคโนโลยีที่ส่งผลต่อโมเมนตัมของตลาดและการแข่งขันในระดับสากล"
    elif category == "MACRO":
        if sentiment == "BULLISH":
            market_perspective = "ช่วยผ่อนคลายความกังวลด้านเศรษฐกิจมหภาค และหนุนกระแสเงินทุนไหลกลับเข้าสู่สินทรัพย์เสี่ยง"
        elif sentiment == "BEARISH":
            market_perspective = "เพิ่มความกังวลด้านแรงกดดันเงินเฟ้อและทิศทางอัตราดอกเบี้ย ส่งผลให้ตลาดอาจเผชิญความผันผวนระยะสั้น"
        else:
            market_perspective = "สะท้อนความไม่แน่นอนของปัจจัยเศรษฐกิจและนโยบายการเงินที่ตลาดยังคงรอดูความชัดเจนเพื่อประเมินทิศทางต่อไป"
    elif category == "COMMODITIES":
        if sentiment == "BULLISH":
            market_perspective = "ราคาสินค้าโภคภัณฑ์ปรับตัวขึ้นจากความตึงเครียดทางภูมิรัฐศาสตร์และอุปทานตึงตัว หนุนหุ้นกลุ่มพลังงาน"
        elif sentiment == "BEARISH":
            market_perspective = "ความต้องการชะลอตัวหรืออุปทานส่วนเกินอาจกดดันราคาสินค้าโภคภัณฑ์และอัตรากำไรของกลุ่มผู้ผลิต"
        else:
            market_perspective = "ความผันผวนของราคาสินค้าโภคภัณฑ์ยังคงขึ้นอยู่กับประเด็นภูมิรัฐศาสตร์และนโยบายการผลิตระดับโลก"
    elif category == "EARNINGS":
        if sentiment == "BULLISH":
            market_perspective = "ผลการดำเนินงานหรือยอดคำสั่งซื้อเติบโตโดดเด่น หนุนมุมมองเชิงบวกของนักวิเคราะห์ต่อแนวโน้มกำไร"
        elif sentiment == "BEARISH":
            market_perspective = "ผลประกอบการหรือยอดขายที่ชะลอตัวลง ส่งผลให้เกิดแรงขายทำกำไรและปรับลดประมาณการกำไร"
        else:
            market_perspective = "ตลาดกำลังจับตารายละเอียดงบการเงินและคาดการณ์ผลการดำเนินงานในไตรมาสถัดไป"
    else:
        market_perspective = "ประเด็นสำคัญที่ส่งผลต่อการปรับสมดุลพอร์ตลงทุนและบรรยากาศการซื้อขายในตลาด"

    ticker_str = " ".join("#" + t for t in tickers)
    ticker_outlook = f"ติดตามความเคลื่อนไหวของกลุ่มหุ้นที่เกี่ยวข้อง {ticker_str} ซึ่งอาจมีความผันผวนตามประเด็นข่าวนี้"

    return [
        f"📌 สาระสำคัญ: {core_summary}",
        f"📊 นัยสำคัญต่อตลาด: {market_perspective}",
        f"🎯 หุ้นที่น่าจับตา: {ticker_outlook}"
    ]

def generate_full_story(item, category, sentiment, tickers, th_title, th_summary):
    """
    Generates 3 rich, distinct paragraphs for the full story modal:
    1. The core headline event and narrative
    2. Background drivers, industry context, and source attribution
    3. Strategic market implications and forward outlook
    """
    cat_thai_map = {
        "TECH": "เทคโนโลยีและปัญญาประดิษฐ์ (AI)",
        "MACRO": "เศรษฐกิจมหภาคและนโยบายการเงิน",
        "COMMODITIES": "พลังงานและสินค้าโภคภัณฑ์",
        "EARNINGS": "ผลการดำเนินงานและผลประกอบการบริษัทจดทะเบียน",
        "ALL": "ตลาดทุนและเศรษฐกิจสากล"
    }
    cat_thai = cat_thai_map.get(category, "ตลาดทุน")

    # Paragraph 1: Headline Narrative
    if th_summary and th_summary != th_title:
        p1 = f"{th_title} โดยมีรายงานว่า {th_summary}"
    else:
        p1 = f"{th_title} ซึ่งเป็นหนึ่งในประเด็นสำคัญที่ตลาดการเงินและนักลงทุนทั่วโลกกำลังให้ความสนใจอย่างใกล้ชิดในรอบวัน"

    # Paragraph 2: Sector and Industry Dynamics
    source_name = item.get("source", "สำนักข่าวต่างประเทศ")
    p2 = f"รายงานจาก {source_name} ระบุว่า ความเคลื่อนไหวดังกล่าวส่งผลต่อมุมมองของนักลงทุนสถาบันและผู้เล่นในตลาด โดยเฉพาะในกลุ่มอุตสาหกรรม{cat_thai} ซึ่งกำลังเผชิญกับปัจจัยขับเคลื่อนทั้งด้านแนวโน้มอุปสงค์-อุปทาน และการปรับสมดุลพอร์ตการลงทุนเพื่อรับมือกับความเปลี่ยนแปลงของสภาวะเศรษฐกิจโลก"

    # Paragraph 3: Strategic Implications & Outlook
    ticker_str = " ".join("#" + t for t in tickers)
    orig_title = item.get("title", "")
    p3 = f"ในมุมมองการลงทุนระยะสั้นถึงระยะกลาง นักวิเคราะห์ประเมินว่าหุ้นกลุ่มที่ได้รับผลกระทบอย่าง {ticker_str} อาจเผชิญความผันผวนของราคาตามทิศทางกระแสข่าว โดยนักลงทุนควรติดตามข้อมูลความคืบหน้าอย่างใกล้ชิดควบคู่กับการประเมินแนวรับแนวต้านทางเทคนิค (อ้างอิงรายงานภาษาอังกฤษ: \"{orig_title}\")"

    return [p1, p2, p3]

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
                    snippet = n.get("snippet", "").strip() or n.get("summary", "").strip()

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
                        "summary": snippet if snippet else title,
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

    # Safety Guard: If articles could not be fetched (e.g. network/rate limit), abort safely without overwriting
    if len(unique_articles) < 3:
        print(f"Warning: Only {len(unique_articles)} articles retrieved. Keeping existing news data to prevent data loss.")
        return

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

        points = generate_key_takeaways(item, category, sentiment, tickers, th_title, th_summary)
        full_article = generate_full_story(item, category, sentiment, tickers, th_title, th_summary)

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
