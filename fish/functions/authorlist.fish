function authorlist
    curl -s 'https://raw.githubusercontent.com/Expensify/App/main/.github/PULL_REQUEST_TEMPLATE.md' | awk '/### PR Author Checklist/,/### Screenshots\/Videos/' | sed -e 's/- \[ \]/- \[x\]/g' | pbcopy
end
