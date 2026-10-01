import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtemp, rm} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

const [playwrightPath, tempParent] = process.argv.slice(2);
if (!playwrightPath || !tempParent) {
    throw new Error('Usage: node test_browser.mjs /path/to/playwright/index.mjs /existing/temp/parent');
}
const {chromium} = await import(pathToFileURL(path.resolve(playwrightPath)).href);
const directory = await mkdtemp(path.join(tempParent, 'k2-browser-'));
const skillDirectory = path.dirname(fileURLToPath(import.meta.url));
const output = path.join(directory, 'dashboard.html');
const reviewUrl = 'https://github.com/Expensify/App/pull/1';
const title = '</script><img src=x onerror="window.injected=true"> Review this';
const generatedAt = '2026-09-30T12:00:00Z';
const task = (section, url, taskTitle, priority = 'No Priority') => ({
    id: `${section}:${url}`, section, url, title: taskTitle, priority,
    repository: 'Expensify/App', author: 'contributor', labels: ['Improvement'],
    createdAt: '2026-09-01T12:00:00Z', updatedAt: generatedAt,
    isDraft: false, isHold: false, isReviewing: false,
});
const snapshot = {
    login: 'francoisl', generatedAt, warnings: [], tasks: [
        task('reviews', reviewUrl, title),
        task('issues', 'https://github.com/Expensify/App/issues/2', 'Old hourly issue', 'Hourly'),
        task('pullRequests', 'https://github.com/Expensify/App/pull/3', 'My pull request'),
    ],
};

function writeSnapshot(value) {
    execFileSync('python3', ['-B', '-c',
        'import json, sys; from pathlib import Path; sys.path.insert(0, sys.argv[1]); '
        + 'import dashboard; dashboard.writeDashboard(Path(sys.argv[2]), json.loads(sys.argv[3]))',
        skillDirectory, output, JSON.stringify(value),
    ]);
}

let browser;
try {
    writeSnapshot(snapshot);
    browser = await chromium.launch({channel: 'chrome', headless: true});
    const context = await browser.newContext({locale: 'en-US', timezoneId: 'UTC', viewport: {width: 1280, height: 960}});
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.clock.install({time: new Date(generatedAt)});
    await page.goto(pathToFileURL(output).href);
    const reviewCheckbox = () => page.locator('#reviews .task > input').first();
    assert.equal(await page.locator('.task').count(), 3);
    assert.equal(await page.locator('#reviews .task-title').textContent(), title);
    assert.equal(await page.locator('.task img').count(), 0);
    assert.equal(await page.evaluate(() => window.injected), undefined);
    assert.equal(await page.locator('#updated').textContent(), 'Updated Sep 30, 2026, 12:00 PM UTC · just now');
    assert.equal(await page.locator('#updated time').getAttribute('datetime'), '2026-09-30T12:00:00.000Z');
    await page.clock.runFor(2 * 60 * 60 * 1000);
    assert.equal(await page.locator('#updated').textContent(), 'Updated Sep 30, 2026, 12:00 PM UTC · 2 hours ago', 'The snapshot age must refresh while the tab stays open');
    await page.clock.setSystemTime(new Date(generatedAt));

    await reviewCheckbox().check();
    assert.equal(await page.locator('#completed-count').textContent(), '1');
    await page.reload();
    assert.equal(await reviewCheckbox().isChecked(), true, 'Checks must survive file:// reloads');
    assert.equal(await page.locator('#completed-count').textContent(), '1');

    await page.locator('#hide-completed').check();
    assert.equal(await page.locator('.task').count(), 2);
    assert.equal(await page.locator('#completed-count').textContent(), '1');
    await page.locator('#hide-completed').uncheck();
    await page.locator('#search').fill('hourly');
    assert.equal(await page.locator('.task').count(), 1);
    await page.locator('#search').fill('');

    writeSnapshot({...snapshot, tasks: snapshot.tasks.slice(1)});
    await page.reload();
    assert.equal(await reviewCheckbox().isChecked(), true, 'Completed items must survive disappearing from GitHub');
    assert.equal(await page.locator('.task').count(), 3);
    assert.match(await page.locator('#reviews .task-meta').textContent(), /Saved from today's checklist/);

    const secondTab = await context.newPage();
    await secondTab.clock.install({time: new Date(generatedAt)});
    await secondTab.goto(pathToFileURL(output).href);
    assert.equal(await secondTab.locator('#reviews .task > input').isChecked(), true, 'Checks must survive reopening');
    await secondTab.close();

    await page.clock.setSystemTime(new Date('2026-10-01T12:00:00Z'));
    await page.evaluate(() => window.dispatchEvent(new Event('focus')));
    assert.equal(await page.locator('#completed-count').textContent(), '0', 'A new local date must start a new checklist');
    assert.equal(await page.locator('.task').count(), 2);
    assert.equal(await page.locator('#stale-notice').isVisible(), true);
    assert.match(await page.locator('#updated').textContent(), /· 1 day ago$/);

    await page.clock.setSystemTime(new Date(generatedAt));
    await page.reload();
    assert.equal(await reviewCheckbox().isChecked(), true, 'Daily reset must preserve earlier days');
    await reviewCheckbox().click();
    await page.reload();
    assert.equal(await page.locator('#completed-count').textContent(), '0');
    assert.equal(await page.locator('#reviews .task').count(), 0);

    await page.evaluate(() => localStorage.setItem('k2-web:v1:francoisl:2026-09-30', '{broken'));
    await page.reload();
    assert.equal(await page.locator('#storage-notice').isVisible(), true);
    assert.equal(await page.locator('.task').count(), 2);
    await page.evaluate(() => localStorage.removeItem('k2-web:v1:francoisl:2026-09-30'));
    writeSnapshot(snapshot);
    await page.reload();
    await page.evaluate(() => { Storage.prototype.setItem = () => { throw new Error('Storage blocked'); }; });
    await reviewCheckbox().check();
    assert.equal(await page.locator('#completed-count').textContent(), '1');
    assert.equal(await page.locator('#storage-notice').isVisible(), true);

    await page.setViewportSize({width: 390, height: 844});
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true);
    assert.deepEqual(errors, []);
    console.log('Browser checks passed: safe rendering, update time, file persistence, filtering, regeneration, daily reset, and storage errors.');
} finally {
    if (browser) await browser.close();
    await rm(directory, {recursive: true, force: true});
}
