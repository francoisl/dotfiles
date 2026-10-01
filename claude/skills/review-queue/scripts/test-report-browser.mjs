import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

const [playwrightPath, tempParent] = process.argv.slice(2);
if (!playwrightPath || !tempParent) throw new Error('Pass an installed Playwright module and an existing temp directory.');
const {chromium} = await import(pathToFileURL(path.resolve(playwrightPath)).href);
const directory = await mkdtemp(path.join(tempParent, 'review-report-'));
const scripts = path.dirname(fileURLToPath(import.meta.url));
const output = path.join(directory, 'latest report.html');
const malicious = '</script><img src=x onerror="window.injected=true">';
const pr = (number, status) => ({
    id: `review-${number}`, repo: 'ExampleRepo', number, status, title: `Example change ${number}`,
    author: 'example-user', url: `https://github.com/ExampleOrg/ExampleRepo/pull/${number}`,
    additions: 8, deletions: 4, churn: 12, files: 2, ci: 'PASSING', corrected: false,
    summary: 'A useful review summary.', findings: [], report: '', reportUrl: '', reviewedAt: '', head: '',
});
const snapshot = {
    batchId: 'test-batch', batchName: 'Example run', owner: 'ExampleOrg', login: 'example-user',
    generatedAt: '2026-09-30T12:00:00Z', queueCapturedAt: '2026-09-30T11:00:00Z', totalAwaiting: 5,
    prs: [pr(1, 'READY_TO_MERGE'), pr(2, 'NEEDS_CHANGES'), pr(3, 'SKIPPED'), pr(4, 'DEFERRED'), pr(5, 'ERROR')],
};
snapshot.prs[1].title = malicious;
snapshot.prs[1].findings = ['src/example.py:12 - Handle a missing value'];
snapshot.prs[1].head = 'a'.repeat(40);
snapshot.prs[1].reviewedAt = '2026-09-30T11:30:00Z';
snapshot.prs[1].report = `## Full review\n\n**Blocking:** Handle \`undefined\`.\n\n- ${malicious}\n- [bad](javascript:alert(1))\n- [malformed](https://%)\n\n\`\`\`js\n${malicious}\n\`\`\``;

function write(value) {
    execFileSync('python3', ['-B', '-c',
        'import importlib.util, json, sys; from pathlib import Path; '
        + 'spec = importlib.util.spec_from_file_location("renderer", sys.argv[1]); '
        + 'module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module); '
        + 'snapshot = json.loads(sys.argv[3]); module.build_snapshot = lambda _: snapshot; '
        + 'sys.argv = [sys.argv[1], str(Path(sys.argv[2]).parent), "--output", sys.argv[2], "--no-open"]; '
        + 'sys.exit(module.main())',
        path.join(scripts, 'render-report.py'), output, JSON.stringify(value),
    ]);
}

let browser;
try {
    write(snapshot);
    const originalHTML = await readFile(output, 'utf8');
    browser = await chromium.launch({channel: 'chrome', headless: true});
    const page = await browser.newPage({locale: 'en-US', timezoneId: 'UTC', viewport: {width: 1280, height: 960}});
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.clock.install({time: new Date('2026-09-30T13:30:00Z')});
    await page.goto(pathToFileURL(output).href);
    assert.equal(await page.locator('.card').count(), 5);
    assert.equal(await page.locator('#updated').textContent(), 'Updated Sep 30, 2026, 11:30 AM UTC · 2 hours ago', 'The newest queue or review time is the update time');
    assert.equal(await page.locator('#updated time').getAttribute('datetime'), '2026-09-30T11:30:00.000Z');
    await page.clock.runFor(60 * 60 * 1000);
    assert.equal(await page.locator('#updated').textContent(), 'Updated Sep 30, 2026, 11:30 AM UTC · 3 hours ago', 'The age must refresh while the tab stays open');
    assert.equal(await page.locator('#pr-1 h2').textContent(), malicious);
    assert.equal(await page.locator('#pr-1 .findings a').getAttribute('href'), `https://github.com/ExampleOrg/ExampleRepo/blob/${'a'.repeat(40)}/src/example.py#L12`);
    await page.locator('#pr-1 details > summary').click();
    await page.locator('#pr-1 .report h2').waitFor();
    assert.equal(await page.locator('#pr-1 .report strong').textContent(), 'Blocking:');
    assert.equal(await page.locator('#pr-1 .report img').count(), 0);
    assert.equal(await page.locator('#pr-1 .report a').count(), 0);
    assert.equal(await page.evaluate(() => window.injected), undefined);

    await page.locator('#pr-0 input').check();
    await page.reload();
    assert.equal(await page.locator('#pr-0 input').isChecked(), true);
    assert.equal(await page.locator('#handled-count').textContent(), '1');
    await page.locator('#hide-handled').check();
    assert.equal(await page.locator('.card:visible').count(), 4);
    await page.locator('#hide-handled').uncheck();
    await page.locator('#status').selectOption('NEEDS_CHANGES');
    assert.equal(await page.locator('.card:visible').count(), 1);
    await page.locator('#status').selectOption('all');
    await page.locator('#search').fill('missing value');
    assert.equal(await page.locator('.card:visible').count(), 1);
    await page.locator('#search').fill('');
    assert.equal(await page.locator('#pr-1 details').getAttribute('open'), null);

    const toggle = page.locator('#pr-1 .collapse-toggle');
    assert.equal(await toggle.getAttribute('aria-expanded'), 'true');
    assert.equal(await toggle.getAttribute('aria-controls'), 'pr-1-body');
    await toggle.click();
    assert.equal(await toggle.getAttribute('aria-expanded'), 'false');
    assert.equal(await page.locator('#pr-1 .findings').isVisible(), false);
    assert.equal(await page.locator('#pr-1 input[type="checkbox"]').isVisible(), true, 'Handled must stay reachable on a collapsed card');
    await page.reload();
    assert.equal(await toggle.getAttribute('aria-expanded'), 'false', 'A collapsed card must stay collapsed after a reload');
    await page.locator('nav a[href="#pr-1"]').click();
    assert.equal(await page.locator('#pr-1 .findings').isVisible(), true, 'Jumping to a PR must expand its card');
    await page.locator('#collapse-all').click();
    assert.equal(await page.locator('.card.collapsed').count(), 5);
    await page.locator('#expand-all').click();
    assert.equal(await page.locator('.card.collapsed').count(), 0);
    await page.locator('#pr-0 .collapse-toggle').click();

    write(snapshot);
    await page.reload();
    assert.equal(await page.locator('#pr-0 input').isChecked(), true, 'Rerendering the same result must retain its handled state');
    assert.equal(await page.locator('#pr-0 .collapse-toggle').getAttribute('aria-expanded'), 'false', 'Rerendering the same result must retain its collapsed state');
    await page.waitForFunction(() => !document.querySelector('script[src]'));
    await page.evaluate(() => { document.querySelector('#pr-0').dataset.unchanged = 'yes'; });
    await page.evaluate(() => window.dispatchEvent(new Event('focus')));
    await page.waitForFunction(() => !document.querySelector('script[src]'));
    assert.equal(await page.locator('#pr-0').getAttribute('data-unchanged'), 'yes', 'Polling unchanged data must not rebuild the cards');

    await page.locator('#pr-1 details > summary').click();
    await page.locator('#search').fill('example');
    await page.locator('#status').selectOption('reviewed');
    await page.locator('#hide-handled').check();
    const currentUrl = page.url();
    const refreshed = {...snapshot, generatedAt: '2026-09-30T14:31:00Z', prs: snapshot.prs.map((item, index) =>
        index === 0 ? {...item, title: 'Refreshed example change'} : item)};
    write(refreshed);
    await page.evaluate(() => window.dispatchEvent(new Event('focus')));
    await page.waitForFunction(() => document.querySelector('#pr-0 h2').textContent === 'Refreshed example change', null, {timeout: 3000});
    assert.equal(await page.locator('#pr-0 input').isChecked(), true, 'Automatic refresh must retain handled state for unchanged reviews');
    assert.equal(await page.locator('#pr-0 .collapse-toggle').getAttribute('aria-expanded'), 'false', 'Automatic refresh must retain collapsed state');
    assert.equal(await page.locator('#pr-1 details').getAttribute('open'), '', 'Automatic refresh must keep an unchanged full review open');
    assert.equal(await page.locator('#search').inputValue(), 'example', 'Automatic refresh must retain search');
    assert.equal(await page.locator('#status').inputValue(), 'reviewed', 'Automatic refresh must retain the verdict filter');
    assert.equal(await page.locator('#hide-handled').isChecked(), true, 'Automatic refresh must retain the handled filter');
    assert.equal(await page.locator('.card:visible').count(), 1);
    assert.equal(page.url(), currentUrl, 'Automatic refresh must reuse the current URL and tab');

    await page.locator('#search').fill('');
    await page.locator('#status').selectOption('all');
    await page.locator('#hide-handled').uncheck();
    write({...refreshed, generatedAt: '2026-09-30T14:32:00Z', prs: refreshed.prs.map((item, index) =>
        index === 0 ? {...item, id: 'auto-revised-review', title: 'Automatically revised review'} : item)});
    await page.clock.runFor(30000);
    await page.waitForFunction(() => document.querySelector('#pr-0 h2').textContent === 'Automatically revised review', null, {timeout: 3000});
    assert.equal(await page.locator('#pr-0 input').isChecked(), false, 'A periodically refreshed changed review must start unchecked');
    assert.equal(await page.locator('#pr-0 .collapse-toggle').getAttribute('aria-expanded'), 'true', 'A periodically refreshed changed review must start expanded');

    write({...snapshot, generatedAt: '2026-09-30T14:33:00Z', batchId: 'next-batch', batchName: 'Next run', prs: [pr(6, 'READY_TO_MERGE')]});
    await page.evaluate(() => window.dispatchEvent(new Event('focus')));
    await page.waitForFunction(() => document.querySelector('#pr-0 h2').textContent === 'Example change 6', null, {timeout: 3000});
    assert.equal(await page.locator('.card').count(), 1, 'A new batch must replace the previous results in the existing tab');
    assert.equal(await page.locator('#handled-count').textContent(), '0', 'A new batch must load its own progress');
    assert.match(await page.locator('#footer').textContent(), /Batch: Next run\./);

    await writeFile(output, originalHTML);
    await page.reload();
    await page.waitForFunction(() => document.querySelector('#pr-0 h2').textContent === 'Example change 6', null, {timeout: 3000});
    assert.equal(await page.locator('.card').count(), 1, 'Loading stale HTML must still pick up the latest companion data');

    const archivedPage = await browser.newPage();
    await archivedPage.clock.install({time: new Date('2026-09-30T14:33:00Z')});
    await archivedPage.goto(pathToFileURL(path.join(directory, 'index.html')).href);
    await page.waitForFunction(() => !document.querySelector('script[src]'));
    await rm(path.join(directory, 'latest report.refresh.js'));
    const missingFile = page.waitForEvent('requestfailed', {predicate: request => request.url().includes('.refresh.js')});
    await page.evaluate(() => window.dispatchEvent(new Event('focus')));
    await missingFile;
    await page.waitForFunction(() => !document.querySelector('script[src]'));
    assert.equal(await page.locator('#pr-0 h2').textContent(), 'Example change 6', 'A missing companion must leave saved results usable');

    write({...snapshot, generatedAt: '2026-09-30T14:34:00Z', batchId: 'next-batch', prs: [pr(7, 'READY_TO_MERGE')]});
    await page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')));
    await page.waitForFunction(() => document.querySelector('#pr-0 h2').textContent === 'Example change 7', null, {timeout: 3000});
    await archivedPage.evaluate(() => window.dispatchEvent(new Event('focus')));
    await archivedPage.clock.runFor(30000);
    assert.equal(await archivedPage.locator('#pr-0 h2').textContent(), 'Example change 6', 'An archived report must not follow latest results');
    await archivedPage.close();

    write({...snapshot, prs: snapshot.prs.map((item, index) => index === 0 ? {...item, id: 'revised-review'} : item)});
    await page.reload();
    assert.equal(await page.locator('#pr-0 input').isChecked(), false, 'A changed review must start unchecked');
    assert.equal(await page.locator('#pr-0 .collapse-toggle').getAttribute('aria-expanded'), 'true', 'A changed review must start expanded');
    write({...snapshot, queueCapturedAt: '', prs: snapshot.prs.map(item => ({...item, reviewedAt: ''}))});
    await page.reload();
    assert.equal(await page.locator('#updated').isVisible(), false, 'A batch without timestamps must not show an update time');
    await page.setViewportSize({width: 390, height: 844});
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    assert.deepEqual(errors, []);
    console.log('Browser checks passed: update time, per-PR cards, safe Markdown, commit links, filtering, collapsing, persistence, automatic refresh, and revised results.');
} finally {
    if (browser) await browser.close();
    await rm(directory, {recursive: true, force: true});
}
