#!/usr/bin/env python3
"""Regression tests for K2 aggregation, failures, and HTML generation."""

import json
import tempfile
import unittest

from pathlib import Path
from unittest.mock import patch

import dashboard


def item(number, **values):
    result = {
        'title': f'Work item {number}',
        'url': f'https://github.com/Expensify/App/pull/{number}',
        'repository': {'nameWithOwner': 'Expensify/App'},
        'author': {'login': 'someone'},
        'updatedAt': '2026-09-30T10:00:00Z',
        'createdAt': '2026-09-01T10:00:00Z',
    }
    result.update(values)
    return result


class DashboardTest(unittest.TestCase):
    def test_reviews_deduplicate_exclude_self_and_sort_latest_first(self):
        old = item(1, updatedAt='2026-09-29T10:00:00Z')
        new = item(2)
        mine = item(3, author={'login': 'FRANCOISL'})
        snapshot = dashboard.buildSnapshot('francoisl', {
            'reviewRequested': [old, new, mine],
            'reviewed': [new, mine],
            'assigned': [new],
            'authored': [new],
        }, [])
        self.assertEqual([task['url'] for task in snapshot['tasks']], [new['url'], old['url'], new['url']])
        self.assertNotEqual(snapshot['tasks'][0]['id'], snapshot['tasks'][2]['id'])

    def test_issue_priority_hold_labels_and_oldest_order(self):
        newer = item(1, createdAt='2026-09-10T10:00:00Z')
        older = item(2, title='[HOLD for fix] Follow up', labels=[
            {'name': 'Daily'}, {'name': 'Hourly'}, {'name': 'Reviewing'},
        ])
        tasks = dashboard.buildSnapshot('francoisl', {'issues': [newer, older]}, [])['tasks']
        self.assertEqual(tasks[0]['url'], older['url'])
        self.assertEqual(tasks[0]['priority'], 'Hourly')
        self.assertTrue(tasks[0]['isHold'])
        self.assertTrue(tasks[0]['isReviewing'])
        self.assertEqual(tasks[1]['priority'], 'No Priority')

    def test_title_cannot_escape_embedded_json(self):
        title = '</script><script>window.injected = true</script> & café'
        snapshot = dashboard.buildSnapshot('francoisl', {'issues': [item(1, title=title)]}, [])
        html = dashboard.renderHtml(snapshot)
        payload = html.split('<script id="snapshot" type="application/json">', 1)[1].split('</script>', 1)[0]
        self.assertNotIn('<', payload)
        self.assertNotIn('&', payload)
        self.assertEqual(json.loads(payload)['tasks'][0]['title'], title)

    def test_unexpected_link_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'Unexpected GitHub item URL'):
            dashboard.buildSnapshot('francoisl', {'issues': [item(1, url='javascript:alert(1)')]}, [])

    def test_partial_failure_keeps_other_lists_and_reports_warning(self):
        def fakeGh(arguments):
            if arguments == ['api', 'user']:
                return {'login': 'francoisl'}
            if 'issues' in arguments:
                raise RuntimeError('Rate limited')
            return [item(1)]

        with patch.object(dashboard, 'runGh', side_effect=fakeGh):
            snapshot = dashboard.fetchData()
        self.assertEqual(len(snapshot['tasks']), 2)
        self.assertEqual(snapshot['warnings'], ['Your assigned issues: Rate limited'])

    def test_total_failure_preserves_existing_dashboard(self):
        def fakeGh(arguments):
            if arguments == ['api', 'user']:
                return {'login': 'francoisl'}
            raise RuntimeError('Offline')

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'dashboard.html'
            output.write_text('Previous dashboard', encoding='utf-8')
            with patch.object(dashboard, 'runGh', side_effect=fakeGh):
                with self.assertRaisesRegex(RuntimeError, 'All GitHub searches failed'):
                    dashboard.writeDashboard(output, dashboard.fetchData())
            self.assertEqual(output.read_text(encoding='utf-8'), 'Previous dashboard')

    def test_regeneration_uses_same_file_and_contains_only_current_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'dashboard.html'
            dashboard.writeDashboard(output, dashboard.buildSnapshot('francoisl', {'issues': [item(1)]}, []))
            dashboard.writeDashboard(output, dashboard.buildSnapshot('francoisl', {'issues': [item(2)]}, []))
            html = output.read_text(encoding='utf-8')
            self.assertNotIn('Work item 1', html)
            self.assertIn('Work item 2', html)
            self.assertEqual(list(Path(directory).iterdir()), [output])


if __name__ == '__main__':
    unittest.main(verbosity=2)
