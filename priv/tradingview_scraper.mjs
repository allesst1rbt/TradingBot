import { chromium } from "playwright";

const input = JSON.parse(process.argv[2]);
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

try {
  await page.goto(input.url, { waitUntil: "domcontentloaded", timeout: input.timeout ?? 30000 });
  await page.waitForTimeout(1500);

  const result = await page.evaluate(() => {
    const text = document.body?.innerText ?? "";
    const meta = (name) => document.querySelector(`meta[name="${name}"]`)?.content ?? null;
    const numeric = (value) => {
      if (!value) return null;
      const match = String(value).replace(/,/g, "").match(/-?\d+(?:\.\d+)?/);
      return match ? Number(match[0]) : null;
    };
    const priceNode = document.querySelector('[data-name="instrument-header-details"] [class*="price"]');
    const price = numeric(priceNode?.textContent) ?? numeric(text.match(/Price\s+(-?\d[\d,.]*)/i)?.[1]);
    const change = numeric(text.match(/Change\s+(-?\d[\d,.]*)\s*%?/i)?.[1]);
    const volume = numeric(text.match(/Volume\s+([\d,.]+)/i)?.[1]);
    const title = document.title || meta("title");

    return { text, title, price, change_pct: change, volume };
  });

  process.stdout.write(JSON.stringify({ ok: true, ...result }));
} catch (error) {
  process.stdout.write(JSON.stringify({ ok: false, error: String(error?.message ?? error) }));
  process.exitCode = 2;
} finally {
  await browser.close();
}
