function mailgunremove --description 'Remove an email address from the Mailgun suppression list'
    set -l API_KEY (cat ~/.config/private/mailgun.key)
    curl -X DELETE -su "api:$API_KEY" "https://api.mailgun.net/v3/mg.expensify.com/bounces/$argv[1]"
end
