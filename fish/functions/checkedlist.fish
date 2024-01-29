function checkedlist
    curl -s 'https://raw.githubusercontent.com/Expensify/App/main/contributingGuides/REVIEWER_CHECKLIST.md' | sed -e 's/- \[ \]/- \[x\]/g' | pbcopy
end
