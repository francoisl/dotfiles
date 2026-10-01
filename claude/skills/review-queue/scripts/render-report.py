#!/usr/bin/env python3
"""Open a standalone, per-PR browser summary of a saved review-queue batch."""

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import webbrowser
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote, urlparse


DEFAULT_OUTPUT = Path.home() / '.local' / 'share' / 'review-queue' / 'index.html'
VERDICTS = ('READY_TO_MERGE', 'MINOR_NITS', 'NEEDS_CHANGES', 'NEEDS_HUMAN')
STATUSES = (*VERDICTS, 'SKIPPED', 'DEFERRED', 'ERROR')
NAME = re.compile(r'^[A-Za-z0-9_.-]+$')
VERDICT_FILE = re.compile(r'^([A-Za-z0-9_.-]+)-(\d+)(?:\.corrected)?\.verdict$')


def timestamp(path):
    return datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()


def pr_identity(item):
    repo, number = item.get('repo'), item.get('number')
    if isinstance(repo, str) and NAME.fullmatch(repo) and str(number).isdigit():
        return repo, int(number)
    parsed = urlparse(item.get('url', ''))
    parts = parsed.path.strip('/').split('/')
    if parsed.scheme == 'https' and parsed.netloc == 'github.com' and len(parts) == 4:
        if parts[2] == 'pull' and parts[3].isdigit() and NAME.fullmatch(parts[1]):
            return parts[1], int(parts[3])
    raise ValueError('A queue item has no valid GitHub PR identity.')


def normalize_pr(item, owner):
    repo, number = pr_identity(item)
    url = item.get('url') or f'https://github.com/{owner}/{repo}/pull/{number}'
    parsed = urlparse(url)
    parts = parsed.path.strip('/').split('/')
    if (parsed.scheme != 'https' or parsed.netloc != 'github.com' or len(parts) != 4
            or parts[1:] != [repo, 'pull', str(number)] or not NAME.fullmatch(parts[0])):
        raise ValueError(f'Unexpected GitHub PR URL: {url!r}')
    return {
        'repo': repo, 'number': number, 'url': url,
        'title': str(item.get('title') or f'{repo} PR {number}'),
        'author': str(item.get('author') or ''),
        'churn': item.get('churn'), 'files': item.get('files'),
        'additions': item.get('additions'), 'deletions': item.get('deletions'),
        'ci': str(item.get('ci') or ''),
    }


def parse_verdict(path):
    fields = {}
    for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
        match = re.match(r'^([A-Z_]+):\s*(.*)$', line)
        if match:
            fields[match[1]] = match[2].strip()
    return fields


def read_review(directory, item, owner):
    result = normalize_pr(item, owner)
    stem = f'{result["repo"]}-{result["number"]}'
    verdict_path = directory / f'{stem}.verdict'
    corrected = directory / f'{stem}.corrected.verdict'
    if corrected.is_file():
        verdict_path = corrected
    fields = parse_verdict(verdict_path) if verdict_path.is_file() else {}
    status = fields.get('VERDICT')
    if status not in VERDICTS:
        status = 'NEEDS_HUMAN'
        summary = 'The verdict is missing or unrecognized. This PR needs your judgement.'
    else:
        summary = fields.get('ONE_LINER') or 'Read the full review before deciding what to do.'
    report_path = verdict_path.with_suffix('.md')
    if fields.get('REPORT'):
        candidate = Path(fields['REPORT'])
        if not candidate.is_absolute():
            candidate = directory / candidate
        candidate = candidate.resolve()
        if candidate.parent == directory and candidate.suffix == '.md':
            report_path = candidate
    report_path = report_path.resolve()
    has_report = report_path.parent == directory and report_path.is_file()
    report = report_path.read_text(encoding='utf-8', errors='replace') if has_report else ''
    top = fields.get('TOP', '')
    findings = [] if top.lower() in ('', 'none', 'n/a') else [finding.strip() for finding in top.split(' | ')]
    signature = hashlib.sha256(json.dumps([fields, report], sort_keys=True).encode()).hexdigest()[:20]
    head = fields.get('HEAD', '')
    result.update({
        'status': status, 'summary': summary, 'findings': findings,
        'report': report, 'reportUrl': report_path.as_uri() if has_report else '',
        'reviewedAt': timestamp(verdict_path) if verdict_path.is_file() else '',
        'corrected': verdict_path == corrected,
        'head': head if re.fullmatch(r'[0-9a-fA-F]{40}', head) else '',
        'blocking': int(fields['BLOCKING']) if fields.get('BLOCKING', '').isdigit() else None,
        'totalFindings': int(fields['TOTAL']) if fields.get('TOTAL', '').isdigit() else None,
        'id': f'{result["url"]}:{signature}',
    })
    return result


def selected_prs(directory):
    targets = directory / 'targets.txt'
    if targets.is_file():
        items = []
        for line in targets.read_text(encoding='utf-8').splitlines():
            if not line.strip():
                continue
            parts = line.split()
            if len(parts) != 2:
                raise ValueError(f'Invalid target: {line!r}')
            items.append({'repo': parts[0], 'number': parts[1]})
        return items
    items = {}
    for path in sorted(directory.glob('*.verdict')):
        match = VERDICT_FILE.fullmatch(path.name)
        if match:
            repo, number = match.groups()
            items[(repo, int(number))] = {'repo': repo, 'number': int(number)}
    return list(items.values())


def build_snapshot(directory):
    directory = directory.resolve()
    if not directory.is_dir():
        raise ValueError(f'No review batch directory at {directory}')
    queue_path = directory / 'queue.json'
    queue = json.loads(queue_path.read_text(encoding='utf-8')) if queue_path.is_file() else {}
    if not isinstance(queue, dict):
        raise ValueError('queue.json must contain a JSON object.')
    owner = queue.get('owner') or os.environ.get('RQ_OWNER', 'Expensify')
    if not isinstance(owner, str) or not NAME.fullmatch(owner):
        raise ValueError('Invalid GitHub owner.')
    selected = queue['review'] if 'review' in queue else selected_prs(directory)
    prs = [read_review(directory, item, owner) for item in selected]
    for bucket, status in [('skipped', 'SKIPPED'), ('deferred', 'DEFERRED'), ('errors', 'ERROR')]:
        for item in queue.get(bucket, []):
            pr = normalize_pr(item, owner)
            pr.update({
                'status': status,
                'summary': str(item.get('reason') or item.get('_error') or 'Not reviewed this run.'),
                'findings': [], 'report': '', 'reportUrl': '', 'reviewedAt': '', 'head': '',
                'blocking': None, 'totalFindings': None, 'corrected': False,
                'id': f'{pr["url"]}:{status}',
            })
            prs.append(pr)
    seen = set()
    unique = []
    for pr in prs:
        if pr['url'] not in seen:
            seen.add(pr['url'])
            unique.append(pr)
    unique.sort(key=lambda pr: (STATUSES.index(pr['status']), pr['repo'].lower(), pr['number']))
    return {
        'batchId': hashlib.sha256(str(directory).encode()).hexdigest()[:24],
        'batchName': directory.name, 'owner': owner, 'login': queue.get('me', ''),
        'generatedAt': datetime.now(timezone.utc).isoformat(),
        'queueCapturedAt': queue.get('captured_at') or (timestamp(queue_path) if queue_path.is_file() else ''),
        'totalAwaiting': queue.get('total_awaiting_review', len(unique)),
        'prs': unique,
    }


def render_html(snapshot):
    template = Path(__file__).with_name('report.html').read_text(encoding='utf-8')
    payload = json.dumps(snapshot, ensure_ascii=True)
    for character in '<>&':
        payload = payload.replace(character, f'\\u{ord(character):04x}')
    return template.replace('__REVIEW_SNAPSHOT__', payload)


def write_html(output, html):
    output.parent.mkdir(parents=True, exist_ok=True)
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=output.parent, delete=False) as file:
            temp_path = Path(file.name)
            file.write(html)
        os.replace(temp_path, output)
    finally:
        if temp_path:
            temp_path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('batch', type=Path, help='Directory containing targets.txt, verdicts, and review reports.')
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT, help='Stable path for the latest browser report.')
    parser.add_argument('--no-open', action='store_true', help='Generate without opening another browser tab.')
    args = parser.parse_args()
    directory = args.batch.expanduser().resolve()
    output = args.output.expanduser().resolve()
    try:
        snapshot = build_snapshot(directory)
        html = render_html(snapshot)
        if output == Path(__file__).with_name('report.html').resolve():
            raise ValueError('The output must not overwrite the report template.')
        for path in dict.fromkeys([directory / 'index.html', output]):
            write_html(path, html)
    except (OSError, ValueError, TypeError, KeyError) as error:
        print(f'Review queue: {error}', file=sys.stderr)
        return 1
    print(f'Browser report: {output.as_uri()}')
    print(f'Batch archive: {(directory / "index.html").as_uri()}')
    for status in STATUSES:
        count = sum(pr['status'] == status for pr in snapshot['prs'])
        if count:
            print(f'{status}: {count}')
    if not args.no_open:
        try:
            if not webbrowser.open(output.as_uri()):
                print('Open the browser report link above.', file=sys.stderr)
        except webbrowser.Error as error:
            print(f'Could not open the browser: {error}. Use the link above.', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
