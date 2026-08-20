const { chromium, devices } = require('playwright');
const fs = require('fs');
const path = require('path');

const outDir = path.join(__dirname, 'test-results');
fs.mkdirSync(outDir, { recursive: true });

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await (await browser.newContext({
    ...devices['Pixel 5'],
    locale: 'pt-BR',
  })).newPage();

  const report = [];
  const note = (k, v) => {
    report.push(`${k}: ${v}`);
    console.log(`${k}:`, v);
  };

  await page.goto('http://localhost:53238/admin-production/1', {
    waitUntil: 'networkidle',
    timeout: 120000,
  });
  await page.waitForTimeout(15000);
  await page.screenshot({ path: path.join(outDir, 'series-editor.png'), fullPage: true });

  const editorChecks = await page.evaluate(() => {
    const canvas = document.querySelector('canvas, flutter-view');
    return {
      url: location.href,
      hasCanvas: !!canvas,
    };
  });
  note('Series editor URL', editorChecks.url);

  await page.goto('http://localhost:53238/admin-production', {
    waitUntil: 'networkidle',
    timeout: 120000,
  });
  await page.waitForTimeout(12000);
  await page.screenshot({ path: path.join(outDir, 'studio-before-create.png'), fullPage: true });

  const viewport = page.viewportSize();
  note('Viewport', `${viewport.width}x${viewport.height}`);
  await page.mouse.click(viewport.width - 30, 30);
  await page.waitForTimeout(6000);
  note('After + URL', page.url());
  await page.screenshot({ path: path.join(outDir, 'create-flow.png'), fullPage: true });

  fs.writeFileSync(path.join(outDir, 'report.txt'), report.join('\n'));
  await browser.close();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
