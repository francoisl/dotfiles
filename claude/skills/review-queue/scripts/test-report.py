#!/usr/bin/env python3
"""Regression tests for saved review results and private browser output."""

import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


def load_module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


renderer = load_module('renderer', 'render-report.py')
fetcher = load_module('fetcher', 'fetch-queue.py')


def metadata(number, **values):
    item = {
        'repo': 'ExampleRepo', 'number': number, 'title': f'Example change {number}',
        'url': f'https://github.com/ExampleOrg/ExampleRepo/pull/{number}',
        'author': 'example-user', 'churn': 12, 'files': 2, 'additions': 8, 'deletions': 4,
    }
    item.update(values)
    return item


def verdict(directory, number, status='NEEDS_CHANGES', corrected=False, report='## Finding\n\nA real issue.'):
    stem = f'ExampleRepo-{number}' + ('.corrected' if corrected else '')
    path = directory / f'{stem}.verdict'
    report_path = directory / f'{stem}.md'
    report_path.write_text(report, encoding='utf-8')
    path.write_text(
        f'PR: ExampleRepo#{number}\nVERDICT: {status}\nBLOCKING: 1\nTOTAL: 1\n'
        f'ONE_LINER: Check the changed behavior.\nTOP: src/example.py:12 - Example issue\n'
        f'REPORT: {report_path}\nHEAD: {"a" * 40}\n', encoding='utf-8',
    )
    return path


class ReportTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def queue(self, **values):
        queue = {'owner': 'ExampleOrg', 'review': [], 'skipped': [], 'deferred': [], 'errors': []}
        queue.update(values)
        (self.directory / 'queue.json').write_text(json.dumps(queue), encoding='utf-8')

    def test_all_queue_buckets_and_missing_verdict_are_visible(self):
        self.queue(review=[metadata(1), metadata(2)], skipped=[metadata(3, reason='draft')],
                   deferred=[metadata(4)], errors=[{'url': metadata(5)['url'], '_error': 'Offline'}])
        verdict(self.directory, 1, status='READY_TO_MERGE')
        prs = renderer.build_snapshot(self.directory)['prs']
        self.assertEqual([pr['status'] for pr in prs], [
            'READY_TO_MERGE', 'NEEDS_HUMAN', 'SKIPPED', 'DEFERRED', 'ERROR',
        ])
        self.assertIn('missing', prs[1]['summary'])
        self.assertEqual(prs[-1]['summary'], 'Offline')
        self.assertEqual(prs[0]['head'], 'a' * 40)

    def test_corrected_review_wins_without_duplicate_pr(self):
        verdict(self.directory, 1)
        verdict(self.directory, 1, status='READY_TO_MERGE', corrected=True, report='Corrected findings.')
        snapshot = renderer.build_snapshot(self.directory)
        self.assertEqual(len(snapshot['prs']), 1)
        self.assertTrue(snapshot['prs'][0]['corrected'])
        self.assertEqual(snapshot['prs'][0]['status'], 'READY_TO_MERGE')
        self.assertEqual(snapshot['prs'][0]['report'], 'Corrected findings.')

    def test_targets_keep_a_failed_pr_that_never_wrote_a_verdict(self):
        (self.directory / 'targets.txt').write_text('ExampleRepo 1\nExampleRepo 2\n', encoding='utf-8')
        verdict(self.directory, 1)
        self.assertEqual(len(renderer.build_snapshot(self.directory)['prs']), 2)

    def test_report_content_cannot_close_the_json_script(self):
        malicious = '</script><img src=x onerror="window.injected=true"> & private text'
        self.queue(review=[metadata(1, title=malicious)])
        verdict(self.directory, 1, report=malicious)
        html = renderer.render_html(renderer.build_snapshot(self.directory))
        payload = html.split('<script id="snapshot" type="application/json">', 1)[1].split('</script>', 1)[0]
        self.assertNotIn('<', payload)
        self.assertNotIn('&', payload)
        self.assertEqual(json.loads(payload)['prs'][0]['report'], malicious)

    def test_report_cannot_read_a_file_outside_the_batch(self):
        path = verdict(self.directory, 1)
        with tempfile.TemporaryDirectory() as other:
            private = Path(other) / 'unrelated.md'
            private.write_text('Unrelated private data', encoding='utf-8')
            path.write_text(f'VERDICT: NEEDS_HUMAN\nREPORT: {private}\n', encoding='utf-8')
            self.assertNotIn('Unrelated private data', renderer.build_snapshot(self.directory)['prs'][0]['report'])
            path.with_suffix('.md').unlink()
            path.with_suffix('.md').symlink_to(private)
            self.assertEqual(renderer.build_snapshot(self.directory)['prs'][0]['report'], '')

    def test_invalid_verdict_and_unsafe_url_do_not_look_ready(self):
        self.queue(review=[metadata(1)])
        verdict(self.directory, 1, status='APPROVED_MAYBE')
        self.assertEqual(renderer.build_snapshot(self.directory)['prs'][0]['status'], 'NEEDS_HUMAN')
        self.queue(review=[metadata(1, url='javascript:alert(1)')])
        with self.assertRaisesRegex(ValueError, 'Unexpected GitHub PR URL'):
            renderer.build_snapshot(self.directory)

    def test_checkbox_identity_survives_regeneration_but_resets_for_changed_findings(self):
        self.queue(review=[metadata(1)])
        path = verdict(self.directory, 1)
        original = renderer.build_snapshot(self.directory)
        self.assertEqual(original['prs'][0]['id'], renderer.build_snapshot(self.directory)['prs'][0]['id'])
        path.with_suffix('.md').write_text('A newly found bug.', encoding='utf-8')
        updated = renderer.build_snapshot(self.directory)
        self.assertEqual(original['batchId'], updated['batchId'])
        self.assertNotEqual(original['prs'][0]['id'], updated['prs'][0]['id'])

    def test_generated_html_is_private_and_can_replace_an_existing_snapshot(self):
        output = self.directory / 'index.html'
        renderer.write_html(output, 'first')
        renderer.write_html(output, 'second')
        self.assertEqual(output.read_text(encoding='utf-8'), 'second')
        self.assertEqual(output.stat().st_mode & 0o777, 0o600)

    def test_latest_report_publishes_private_refresh_data_without_refreshing_the_archive(self):
        self.queue(review=[metadata(1)])
        verdict(self.directory, 1, report='</script><img src=x onerror="window.injected=true">')
        output = self.directory / 'latest' / 'custom report.html'
        args = ['render-report.py', str(self.directory), '--output', str(output), '--no-open']
        with patch('sys.argv', args), patch('builtins.print'), patch.object(renderer.webbrowser, 'open') as open_browser:
            self.assertEqual(renderer.main(), 0)
            open_browser.assert_not_called()

        def snapshot(path):
            return json.loads(path.read_text(encoding='utf-8').split(
                '<script id="snapshot" type="application/json">', 1)[1].split('</script>', 1)[0])

        latest = snapshot(output)
        archive = snapshot(self.directory / 'index.html')
        self.assertEqual(latest['refreshFile'], 'custom report.refresh.js')
        self.assertNotIn('refreshFile', archive)
        refresh = output.with_suffix('.refresh.js')
        script = refresh.read_text(encoding='utf-8')
        self.assertTrue(script.startswith('window.reviewQueueRefresh('))
        self.assertEqual(json.loads(script.removeprefix('window.reviewQueueRefresh(').removesuffix(');\n')), latest)
        self.assertNotIn('<', script)
        self.assertEqual(refresh.stat().st_mode & 0o777, 0o600)

        verdict(self.directory, 1, status='READY_TO_MERGE', report='Updated review.')
        with patch('sys.argv', args), patch('builtins.print'):
            self.assertEqual(renderer.main(), 0)
        self.assertIn('Updated review.', refresh.read_text(encoding='utf-8'))
        self.assertEqual(snapshot(output)['prs'][0]['status'], 'READY_TO_MERGE')

    def test_fetcher_saves_metadata_without_changing_selection(self):
        output = self.directory / 'queue.json'
        raw = {
            'number': 1, 'title': 'Long title ' * 20, 'url': metadata(1)['url'],
            'author': {'login': 'example-user'}, 'additions': 8, 'deletions': 4, 'changedFiles': 2,
        }

        def fake_gh(args, **_):
            from subprocess import CompletedProcess
            if args[:2] == ['api', 'user']:
                payload = 'example-user'
            elif args[:2] == ['search', 'prs']:
                payload = json.dumps([{'url': metadata(1)['url']}])
            else:
                payload = json.dumps(raw)
            return CompletedProcess(args, 0, payload, '')

        with patch.object(fetcher, 'gh', side_effect=fake_gh), patch.object(fetcher, 'triage', return_value=None):
            with patch('sys.argv', ['fetch-queue.py', '--output', str(output)]), patch('builtins.print'):
                fetcher.main()
        queue = json.loads(output.read_text(encoding='utf-8'))
        self.assertEqual(queue['review'][0]['title'], raw['title'])
        self.assertEqual(queue['review'][0]['additions'], 8)
        self.assertEqual(queue['review'][0]['deletions'], 4)
        self.assertIn('captured_at', queue)
        self.assertEqual(output.stat().st_mode & 0o777, 0o600)

    def test_batch_keeps_failed_reviews_and_builds_the_browser_report(self):
        batch = self.directory / 'batch'
        home = self.directory / 'home'
        env = dict(os.environ, HOME=str(home), RQ_CLONE_ROOT=str(self.directory / 'missing-clones'),
                   RQ_OWNER='ExampleOrg', RQ_JOBS='2')
        result = subprocess.run([
            'bash', str(Path(__file__).with_name('run-batch.sh')), str(batch), 'medium',
            'ExampleRepo', '1', 'OtherRepo', '2',
        ], env=env, capture_output=True, text=True, timeout=30, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((batch / 'index.html').is_file(), result.stdout)
        self.assertTrue((home / '.local' / 'share' / 'review-queue' / 'index.html').is_file())
        prs = renderer.build_snapshot(batch)['prs']
        self.assertEqual(len(prs), 2)
        self.assertTrue(all(pr['status'] == 'NEEDS_HUMAN' for pr in prs))
        self.assertTrue(all('No local clone' in pr['summary'] for pr in prs))


if __name__ == '__main__':
    unittest.main(verbosity=2)
