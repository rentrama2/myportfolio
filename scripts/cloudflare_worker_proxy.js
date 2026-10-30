/**
 * Cloudflare Worker: Yahoo Finance & Finnhub CORS Proxy
 * --------------------------------------------------------
 * Deploy this free Worker to Cloudflare to enable 100% Real-Time
 * In-Browser stock price fetching with zero CORS errors.
 * 
 * Free Tier: 100,000 requests / day (100% free forever)
 * 
 * Instructions:
 * 1. Go to https://dash.cloudflare.com/ -> Workers & Pages -> Create Application
 * 2. Click "Create Worker", name it (e.g. "my-stock-proxy"), and click "Deploy"
 * 3. Click "Edit code", replace all code with this file, and click "Save and Deploy"
 * 4. Copy your worker URL (e.g. https://my-stock-proxy.yourname.workers.dev)
 * 5. In your Portfolio web app, click "ตั้งค่า Real-Time Data Source" and paste the URL!
 */

export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight OPTIONS request
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, OPTIONS",
          "Access-Control-Allow-Headers": "*",
          "Access-Control-Max-Age": "86400",
        },
      });
    }

    const url = new URL(request.url);
    const symbol = url.searchParams.get("symbol") || url.searchParams.get("s");
    const targetUrl = url.searchParams.get("url");

    let fetchTarget = "";
    if (targetUrl) {
      fetchTarget = decodeURIComponent(targetUrl);
    } else if (symbol) {
      const sym = symbol.trim().toUpperCase().replace(".", "-");
      fetchTarget = `https://query1.finance.yahoo.com/v8/finance/chart/${sym}?range=1d&interval=1m&includePrePost=true`;
    } else {
      return new Response(JSON.stringify({ 
        status: "ok", 
        message: "Stock CORS Proxy is running. Use ?symbol=NVDA or ?url=..." 
      }), {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        }
      });
    }

    try {
      const yahooResponse = await fetch(fetchTarget, {
        method: "GET",
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Accept": "application/json"
        }
      });

      const body = await yahooResponse.text();
      return new Response(body, {
        status: yahooResponse.status,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, OPTIONS",
          "Access-Control-Allow-Headers": "*",
          "Cache-Control": "public, max-age=5"
        }
      });
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        }
      });
    }
  }
};
