import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtemp, rm} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

const [playwrightPath, tempParent] = process.argv.slice(2);
if (!playwrightPath || !tempParent) throw new Error('Pass an installed Playwright module and an existing temp directory.');
const {chromium} = await import(pathToFileURL(path.resolve(playwrightPath)).href);
const directory = await mkdtemp(path.join(tempParent, 'review-report-'));
const scripts = path.dirname(fileURLToPath(import.meta.url));
const output = path.join(directory, 'index.html');
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
        + 'module.write_html(Path(sys.argv[2]), module.render_html(json.loads(sys.argv[3])))',
        path.join(scripts, 'render-report.py'), output, JSON.stringify(value),
    ]);
}

let browser;
try {
    write(snapshot);
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
    console.log('Browser checks passed: update time, per-PR cards, safe Markdown, commit links, filtering, collapsing, persistence, and revised results.');
} finally {
    if (browser) await browser.close();
    await rm(directory, {recursive: true, force: true});
}
