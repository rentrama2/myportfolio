#!/usr/bin/env python3
import json
import os
import urllib.request
import datetime

# Tickers to fetch
DEFAULT_TICKERS = [
    "GOOGL", "MSFT", "JEPI", "JEPQ", "VTI", 
    "VOO", "QQQ", "QQQM", "SCHD", "AAPL", 
    "NVDA", "VXUS", "SPY", "AMZN", "META", 
    "TSLA", "AMD", "NFLX", "COIN", "PLTR", 
    "SOXX", "SMH", "INTC", "BRK-B"
]

def fetch_json(url, timeout=10):
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))

def fetch_yahoo_price(ticker):
    try:
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d"
        data = fetch_json(url)
        meta = data["chart"]["result"][0]["meta"]
        price = meta.get("regularMarketPrice") or meta.get("chartPreviousClose") or meta.get("previousClose")
        return round(float(price), 4) if price else None
    except Exception as e:
        print(f"Error fetching {ticker}: {e}")
        return None

def fetch_usd_thb():
    # 1. Try Yahoo Finance THB=X
    rate = fetch_yahoo_price("THB=X")
    if rate and rate > 0:
        return round(rate, 4)
    
    # 2. Try Fawaz Ahmed Currency API
    try:
        url = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json"
        data = fetch_json(url)
        return round(float(data["usd"]["thb"]), 4)
    except Exception as e:
        print(f"Error fetching FX from Fawaz Ahmed: {e}")

    # 3. Try open.er-api
    try:
        url = "https://open.er-api.com/v6/latest/USD"
        data = fetch_json(url)
        return round(float(data["rates"]["THB"]), 4)
    except Exception as e:
        print(f"Error fetching FX from er-api: {e}")

    return None

def main():
    prices_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "prices.json")
    
    existing_data = {}
    if os.path.exists(prices_file):
        try:
            with open(prices_file, "r", encoding="utf-8") as f:
                existing_data = json.load(f)
        except Exception:
            existing_data = {}

    tickers = set(DEFAULT_TICKERS)
    if "prices" in existing_data and isinstance(existing_data["prices"], dict):
        for k in existing_data["prices"].keys():
            if k and k != "CASH":
                tickers.add(k.upper().strip())

    print(f"Fetching prices for {len(tickers)} tickers...")
    prices = existing_data.get("prices", {})
    success_count = 0
    
    for ticker in sorted(tickers):
        price = fetch_yahoo_price(ticker)
        if price:
            prices[ticker] = price
            success_count += 1
            print(f"  [OK] {ticker}: {price}")
        else:
            print(f"  [FAIL] {ticker} (kept previous: {prices.get(ticker)})")

    print("Fetching USD/THB rate...")
    usd_thb = fetch_usd_thb() or existing_data.get("fx", {}).get("USDTHB", 33.40)
    print(f"  USD/THB: {usd_thb}")

    now_utc = datetime.datetime.now(datetime.timezone.utc)
    # Thai time UTC+7
    thai_tz = datetime.timezone(datetime.timedelta(hours=7))
    now_thai = now_utc.astimezone(thai_tz)
    
    thai_months = ["", "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
    thai_str = f"{now_thai.day} {thai_months[now_thai.month]} {now_thai.year + 543} {now_thai.strftime('%H:%M')} น."

    output = {
        "updated_at": now_utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "updated_at_thai": thai_str,
        "fx": {
            "USDTHB": usd_thb
        },
        "prices": prices
    }

    os.makedirs(os.path.dirname(prices_file), exist_ok=True)
    with open(prices_file, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"Successfully updated {prices_file} with {success_count} prices at {thai_str}")

if __name__ == "__main__":
    main()
