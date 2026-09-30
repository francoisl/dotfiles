#!/usr/bin/env python3
"""Build a standalone daily GitHub checklist using the authenticated gh account."""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import webbrowser

from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse


PR_FIELDS = 'title,url,updatedAt,author,repository,isDraft'
ISSUE_FIELDS = 'title,url,labels,updatedAt,createdAt,repository'
PRIORITIES = ('Hourly', 'Daily', 'Weekly', 'Monthly', 'No Priority')
SEARCH_LIMIT = 1000
DEFAULT_OUTPUT = Path.home() / '.local' / 'share' / 'k2-web' / 'dashboard.html'
SEARCHES = {
    'reviewRequested': ('PRs requesting your review', [
        'search', 'prs', '--state=open', '--review-requested=@me', '--owner=Expensify',
        f'--json={PR_FIELDS}', f'--limit={SEARCH_LIMIT}',
    ]),
    'reviewed': ('PRs you have reviewed', [
        'search', 'prs', '--state=open', '--reviewed-by=@me', '--owner=Expensify',
        f'--json={PR_FIELDS}', f'--limit={SEARCH_LIMIT}',
    ]),
    'issues': ('Your assigned issues', [
        'search', 'issues', '--state=open', '--assignee=@me', '--repo=Expensify/Expensify',
        '--repo=Expensify/App', '--repo=Expensify/Insiders',
        f'--json={ISSUE_FIELDS}', f'--limit={SEARCH_LIMIT}',
    ]),
    'assigned': ('PRs assigned to you', [
        'search', 'prs', '--state=open', '--assignee=@me', '--owner=Expensify',
        f'--json={PR_FIELDS}', f'--limit={SEARCH_LIMIT}',
    ]),
    'authored': ('Your authored PRs', [
        'search', 'prs', '--state=open', '--author=@me', '--owner=Expensify',
        f'--json={PR_FIELDS}', f'--limit={SEARCH_LIMIT}',
    ]),
}


def runGh(arguments):
    """Read JSON from gh, surfacing failed commands and invalid responses."""
    try:
        result = subprocess.run(
            ['gh', *arguments], capture_output=True, text=True, timeout=120, check=False,
        )
    except FileNotFoundError as error:
        raise RuntimeError('GitHub CLI is missing. Install gh and run gh auth login.') from error
    except subprocess.TimeoutExpired as error:
        raise RuntimeError('GitHub request timed out after 120 seconds.') from error
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f'gh exited with status {result.returncode}.')
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError('GitHub CLI returned invalid JSON.') from error


def fetchData():
    user = runGh(['api', 'user'])
    if not isinstance(user, dict) or not isinstance(user.get('login'), str) or not user['login']:
        raise RuntimeError('GitHub did not return the authenticated user login.')
    results = {}
    warnings = []
    with ThreadPoolExecutor(max_workers=len(SEARCHES)) as executor:
        futures = {executor.submit(runGh, arguments): key for key, (_, arguments) in SEARCHES.items()}
        for future in as_completed(futures):
            key = futures[future]
            label = SEARCHES[key][0]
            try:
                items = future.result()
                if not isinstance(items, list) or any(not isinstance(item, dict) for item in items):
                    raise RuntimeError('GitHub search returned an unexpected response.')
                results[key] = items
                if len(items) >= SEARCH_LIMIT:
                    warnings.append(f'{label}: reached the {SEARCH_LIMIT}-item limit; the list may be incomplete.')
            except RuntimeError as error:
                warnings.append(f'{label}: {error}')
    if not results:
        raise RuntimeError('All GitHub searches failed. The previous dashboard is preserved.\n' + '\n'.join(warnings))
    return buildSnapshot(user['login'], results, sorted(warnings))


def uniqueItems(items):
    """Keep the newest copy of each item, validating its GitHub link."""
    unique = {}
    for item in sorted(items, key=lambda value: value.get('updatedAt', ''), reverse=True):
        url = item.get('url', '')
        parsed = urlparse(url)
        if parsed.scheme != 'https' or parsed.netloc != 'github.com':
            raise RuntimeError(f'Unexpected GitHub item URL: {url!r}')
        unique.setdefault(url, item)
    return list(unique.values())


def makeTask(item, section):
    labels = [label['name'] for label in item.get('labels', [])]
    return {
        'id': f'{section}:{item["url"]}',
        'section': section,
        'url': item['url'],
        'title': item['title'],
        'repository': item.get('repository', {}).get('nameWithOwner', ''),
        'author': item.get('author', {}).get('login', ''),
        'updatedAt': item.get('updatedAt', ''),
        'createdAt': item.get('createdAt', ''),
        'labels': labels,
        'priority': next((priority for priority in PRIORITIES[:-1] if priority in labels), 'No Priority'),
        'isDraft': bool(item.get('isDraft')),
        'isHold': '[hold' in item['title'].lower(),
        'isReviewing': 'Reviewing' in labels,
    }


def buildSnapshot(login, results, warnings):
    reviews = uniqueItems(results.get('reviewRequested', []) + results.get('reviewed', []))
    reviews = [item for item in reviews if item.get('author', {}).get('login', '').lower() != login.lower()]
    issues = uniqueItems(results.get('issues', []))
    issues.sort(key=lambda item: item.get('createdAt', ''))
    pullRequests = uniqueItems(results.get('assigned', []) + results.get('authored', []))
    return {
        'login': login,
        'generatedAt': datetime.now(timezone.utc).isoformat(),
        'warnings': warnings,
        'tasks': (
            [makeTask(item, 'reviews') for item in reviews]
            + [makeTask(item, 'issues') for item in issues]
            + [makeTask(item, 'pullRequests') for item in pullRequests]
        ),
    }


def renderHtml(snapshot):
    template = Path(__file__).with_name('dashboard.html').read_text(encoding='utf-8')
    payload = json.dumps(snapshot, ensure_ascii=True)
    for character in '<>&':
        payload = payload.replace(character, f'\\u{ord(character):04x}')
    return template.replace('__K2_SNAPSHOT__', payload)


def writeDashboard(output, snapshot):
    """Replace the HTML only after the full snapshot has been rendered successfully."""
    html = renderHtml(snapshot)
    output.parent.mkdir(parents=True, exist_ok=True)
    tempPath = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=output.parent, delete=False) as file:
            tempPath = Path(file.name)
            file.write(html)
        os.replace(tempPath, output)
    finally:
        if tempPath is not None:
            tempPath.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT, help='Stable output path for the HTML file.')
    parser.add_argument('--no-open', action='store_true', help='Generate the dashboard without opening a browser tab.')
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    try:
        snapshot = fetchData()
        writeDashboard(output, snapshot)
    except (RuntimeError, OSError) as error:
        print(f'K2: {error}', file=sys.stderr)
        return 1
    print(f'Dashboard: {output}')
    print(f'Open: {output.as_uri()}')
    for section, label in [('reviews', 'PRs to review'), ('issues', 'Issues'), ('pullRequests', 'Your PRs')]:
        count = sum(task['section'] == section for task in snapshot['tasks'])
        print(f'{label}: {count}')
    for warning in snapshot['warnings']:
        print(f'Warning: {warning}', file=sys.stderr)
    if not args.no_open:
        try:
            if not webbrowser.open(output.as_uri()):
                print('Open the file link above in your browser.', file=sys.stderr)
        except webbrowser.Error as error:
            print(f'Could not open your browser: {error}. Use the file link above.', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
