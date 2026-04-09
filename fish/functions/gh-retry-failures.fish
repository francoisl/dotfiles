function gh-retry-failures --description "Watch a PR's CI and retry failed jobs up to 5 times"
    if test (count $argv) -lt 1
        echo "Usage: gh-retry-failures <PR-number>"
        return 1
    end

    set pr $argv[1]
    set max_retries 5

    for attempt in (seq 1 $max_retries)
        echo "⏳ Waiting for checks on PR #$pr (attempt $attempt/$max_retries)..."
        gh pr checks $pr --watch 2>/dev/null

        if test $status -eq 0
            echo "✅ All checks passed!"
            _fl_notify "PR #$pr" "All checks passed ✅"
            return 0
        end

        echo "❌ Some checks failed."

        if test $attempt -eq $max_retries
            echo "Giving up after $max_retries attempts."
            _fl_notify "PR #$pr" "Checks still failing after $max_retries attempts ❌"
            gh pr checks $pr
            return 1
        end

        echo "🔄 Rerunning failed jobs..."
        set head_sha (gh pr view $pr --json headRefOid -q .headRefOid)

        set reran 0
        for run_id in (gh api "repos/{owner}/{repo}/actions/runs?head_sha=$head_sha&per_page=100" -q '.workflow_runs[] | select(.conclusion == "failure") | .id')
            echo "  Rerunning run $run_id..."
            if gh api repos/{owner}/{repo}/actions/runs/$run_id/rerun-failed-jobs --method POST 2>/dev/null
                set reran (math $reran + 1)
            else
                echo "  ⚠️  Could not rerun run $run_id, skipping"
            end
        end

        if test $reran -eq 0
            echo "No failed runs could be rerun."
            _fl_notify "PR #$pr" "Failed runs could not be rerun ❌"
            gh pr checks $pr
            return 1
        end

        sleep 5
    end
end
