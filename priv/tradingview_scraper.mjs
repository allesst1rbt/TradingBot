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
      const raw = String(value).trim().replace(/%/g, "");
      const normalized = raw.includes(",")
        ? raw.replace(/\./g, "").replace(",", ".")
        : raw.replace(/,/g, "");
      const match = normalized.match(/-?\d+(?:\.\d+)?/);
      return match ? Number(match[0]) : null;
    };
    const priceNode = document.querySelector('[data-name="instrument-header-details"] [class*="price"]');
    const price = numeric(priceNode?.textContent) ?? numeric(text.match(/\n(-?\d[\d.,]*)\nD\n(?:BRL|USD|EUR)/)?.[1]) ?? numeric(text.match(/Price\s+(-?\d[\d.,]*)/i)?.[1]);
    const change = numeric(text.match(/Change\s+(-?\d[\d,.]*)\s*%?/i)?.[1]);
    const volume = numeric(text.match(/Volume\s+([\d,.]+)/i)?.[1]);
    const title = document.title || meta("title");
    const news =
      Array.from(document.querySelectorAll("a[href*='/news/'], article a, [class*='news'] a"))
        .map((a) => ({ headline: a.textContent?.trim() ?? "", source: a.href || "" }))
        .filter((n) => n.headline.length > 10)
        .slice(0, 10);

    return { text, title, price, change_pct: change, volume, news };
  });

  process.stdout.write(JSON.stringify({ ok: true, ...result }));
} catch (error) {
  process.stdout.write(JSON.stringify({ ok: false, error: String(error?.message ?? error) }));
  process.exitCode = 2;
} finally {
  await browser.close();
}
