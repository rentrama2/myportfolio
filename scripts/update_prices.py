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
    sym = ticker.replace('.', '-')
    endpoints = [
        f"https://query2.finance.yahoo.com/v8/finance/chart/{sym}?interval=1d",
        f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}?interval=1d",
        f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}"
    ]
    for url in endpoints:
        try:
            data = fetch_json(url)
            meta = data["chart"]["result"][0]["meta"]
            price = meta.get("regularMarketPrice") or meta.get("chartPreviousClose") or meta.get("previousClose")
            if price:
                return round(float(price), 4)
        except Exception:
            continue
    print(f"Error fetching {ticker}")
    return None

def fetch_yahoo_stock(ticker):
    sym = ticker.replace('.', '-')
    endpoints = [
        f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}?range=1d&interval=1m&includePrePost=true",
        f"https://query2.finance.yahoo.com/v8/finance/chart/{sym}?range=1d&interval=1m&includePrePost=true",
        f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}?range=1d&interval=5m&includePrePost=true",
        f"https://query1.finance.yahoo.com/v8/finance/chart/{sym}?interval=1d"
    ]
    for url in endpoints:
        try:
            data = fetch_json(url)
            if not data or "chart" not in data or not data["chart"].get("result"):
                continue
            meta = data["chart"]["result"][0]["meta"]
            reg_price = meta.get("regularMarketPrice") or meta.get("chartPreviousClose") or meta.get("previousClose")
            if not reg_price:
                continue
            reg_price = round(float(reg_price), 4)

            ext_info = None
            periods = meta.get("currentTradingPeriod", {})
            pre_p = periods.get("pre", {})
            reg_p = periods.get("regular", {})
            post_p = periods.get("post", {})

            now_ts = int(datetime.datetime.now(datetime.timezone.utc).timestamp())

            # Detect current active trading session strictly based on timestamps
            session = None
            if pre_p.get("start") and reg_p.get("start") and pre_p["start"] <= now_ts < reg_p["start"]:
                session = "PRE"
            elif reg_p.get("end") and post_p.get("end") and reg_p["end"] <= now_ts <= post_p["end"]:
                session = "POST"

            # Only extract extended hours data if market is currently in an active PRE or POST session
            if session:
                timestamps = data["chart"]["result"][0].get("timestamp", [])
                quotes_list = []
                indicators = data["chart"]["result"][0].get("indicators", {})
                if indicators and "quote" in indicators and indicators["quote"]:
                    quotes_list = indicators["quote"][0].get("close", [])

                # Find the most recent non-null quote tick traded within the active session
                session_price = None
                if quotes_list and timestamps:
                    for ts, cl in zip(reversed(timestamps), reversed(quotes_list)):
                        if cl is not None:
                            if session == "PRE" and pre_p.get("start") and ts >= pre_p["start"]:
                                session_price = cl
                                break
                            elif session == "POST" and reg_p.get("end") and ts >= reg_p["end"]:
                                session_price = cl
                                break

                # Fallback to meta prices if quote series is empty
                if session_price is None:
                    if session == "PRE":
                        session_price = meta.get("preMarketPrice") or meta.get("fulldayPrice")
                    elif session == "POST":
                        session_price = meta.get("postMarketPrice") or meta.get("fulldayPrice")

                if session_price and reg_price and abs(float(session_price) - float(reg_price)) > 0.0001:
                    diff = round(float(session_price) - float(reg_price), 2)
                    pct = round((diff / float(reg_price)) * 100, 2)
                    ext_info = {
                        "session": session,
                        "price": round(float(session_price), 2),
                        "regularPrice": round(float(reg_price), 2),
                        "change": diff,
                        "changePct": pct,
                        "time": int(now_ts)
                    }

            return reg_price, ext_info
        except Exception:
            continue
    print(f"Error fetching {ticker}")
    return None, None

def fetch_yahoo_index(ticker):
    endpoints = [
        f"https://query2.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d",
        f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d",
        f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}"
    ]
    for url in endpoints:
        try:
            data = fetch_json(url)
            meta = data["chart"]["result"][0]["meta"]
            price = meta.get("regularMarketPrice") or meta.get("chartPreviousClose") or meta.get("previousClose")
            prev = meta.get("chartPreviousClose") or meta.get("previousClose") or price
            if price is not None:
                price = round(float(price), 2)
                prev = round(float(prev), 2) if prev is not None else price
                diff = round(price - prev, 2)
                pct = round((diff / prev) * 100, 2) if prev > 0 else 0.0
                return {
                    "price": price,
                    "prevClose": prev,
                    "change": diff,
                    "changePct": pct
                }
        except Exception:
            continue
    print(f"Error fetching index {ticker}")
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
    extended_hours = existing_data.get("extended_hours", {})
    success_count = 0
    
    for ticker in sorted(tickers):
        reg_price, ext_info = fetch_yahoo_stock(ticker)
        if reg_price:
            prices[ticker] = reg_price
            if ext_info:
                extended_hours[ticker] = ext_info
                print(f"  [OK] {ticker}: {reg_price} ({ext_info['session']}: ${ext_info['price']} {ext_info['changePct']:+0.2f}%)")
            else:
                if ticker in extended_hours:
                    del extended_hours[ticker]
                print(f"  [OK] {ticker}: {reg_price}")
            success_count += 1
        else:
            print(f"  [FAIL] {ticker} (kept previous: {prices.get(ticker)})")

    print("Fetching USD/THB rate...")
    usd_thb = fetch_usd_thb() or existing_data.get("fx", {}).get("USDTHB", 33.40)
    print(f"  USD/THB: {usd_thb}")

    print("Fetching US & Global Market Indices (^DJI, ^GSPC, ^IXIC, ^NDX, ^VIX, GC=F, CL=F, DX-Y.NYB)...")
    indices_config = {
        "^DJI": "Dow Jones",
        "^GSPC": "S&P 500",
        "^IXIC": "Nasdaq",
        "^NDX": "NDX 100",
        "^VIX": "VIX Index",
        "GC=F": "Gold (XAU)",
        "CL=F": "WTI Crude Oil",
        "DX-Y.NYB": "DXY Index"
    }
    indices = existing_data.get("indices", {})
    for sym, name in indices_config.items():
        idx_data = fetch_yahoo_index(sym)
        if idx_data:
            idx_data["name"] = name
            indices[sym] = idx_data
            print(f"  [OK Index] {name} ({sym}): {idx_data['price']} ({idx_data['changePct']:+0.2f}%)")
        else:
            print(f"  [FAIL Index] {name} ({sym}) (kept previous: {indices.get(sym)})")

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
        "indices": indices,
        "prices": prices,
        "extended_hours": extended_hours
    }

    os.makedirs(os.path.dirname(prices_file), exist_ok=True)
    with open(prices_file, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"Successfully updated {prices_file} with {success_count} prices at {thai_str}")

if __name__ == "__main__":
    main()
