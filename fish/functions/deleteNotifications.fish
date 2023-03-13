function deleteNotifications
    pushd (pwd)
    cd ~/Expensidev
    vssh "sqlite3 /var/auth/main.db 'delete from notifications;'"
    echo 'All notifications deleted!'
    vssh "sqlite3 /var/bedrock/main.db 'delete from jobs where name = 'www-prod/EmailNotification' or name glob '*Scrape*' or name glob '*CheckPublicEmail*';'"
    echo 'All jobs deleted!'
    popd
end
