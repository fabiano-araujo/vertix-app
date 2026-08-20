const { chromium, devices } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    ...devices['Pixel 5'],
    locale: 'pt-BR',
  });
  const page = await context.newPage();

  const logs = [];
  page.on('console', (msg) => logs.push(`[console] ${msg.type()}: ${msg.text()}`));
  page.on('pageerror', (err) => logs.push(`[pageerror] ${err.message}`));

  await page.goto('http://localhost:53238/', { waitUntil: 'networkidle', timeout: 120000 });
  await page.waitForTimeout(8000);

  const enableA11y = page.getByRole('button', { name: 'Enable accessibility' });
  if (await enableA11y.count()) {
    await enableA11y.click({ timeout: 5000 }).catch(() => {});
    await page.waitForTimeout(1500);
  }

  const producoes = page.getByText('Producoes', { exact: true });
  if (await producoes.count()) {
    await producoes.first().click({ timeout: 10000 });
    await page.waitForTimeout(5000);
  } else {
    await page.goto('http://localhost:53238/admin-production', {
      waitUntil: 'networkidle',
      timeout: 120000,
    });
    await page.waitForTimeout(8000);
  }

  await page.screenshot({ path: 'test-results/studio-list.png', fullPage: true });

  const bodyText = await page.locator('body').innerText().catch(() => '');
  const hasStudio = /Studio|Novo microdrama|Buscar serie/i.test(bodyText);
  const hasOverflow = /OVERFLOWED BY/i.test(bodyText);
  const hasNullScene = /Cena null/i.test(bodyText);

  console.log('URL:', page.url());
  console.log('Has studio UI:', hasStudio);
  console.log('Has overflow banner:', hasOverflow);
  console.log('Has Cena null:', hasNullScene);
  console.log('Body snippet:', bodyText.slice(0, 500).replace(/\s+/g, ' '));

  const addButtons = page.locator('[aria-label="Novo microdrama"], button:has-text("+")');
  if (await addButtons.count()) {
    await addButtons.first().click({ timeout: 5000 }).catch(async () => {
      const plus = page.getByRole('button').filter({ hasText: '+' });
      if (await plus.count()) await plus.first().click();
    });
    await page.waitForTimeout(6000);
    await page.screenshot({ path: 'test-results/new-series-editor.png', fullPage: true });
    const editorText = await page.locator('body').innerText().catch(() => '');
    console.log('Editor snippet:', editorText.slice(0, 800).replace(/\s+/g, ' '));
    console.log('Editor has chat brief:', /Comece a criar|Assistente de redação|Novo microdrama/i.test(editorText));
    console.log('Editor overflow:', /OVERFLOWED BY/i.test(editorText));
  } else {
    console.log('Add/new series button not found');
  }

  if (logs.length) {
    console.log('Recent logs:');
    logs.slice(-20).forEach((line) => console.log(line));
  }

  await browser.close();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
