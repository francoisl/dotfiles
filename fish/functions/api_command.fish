function api_command
    set command_name (string replace -- "-api" "" $argv)
    echo "$(string join \n -- 'curl -sk \'https://www.expensify.com.dev/api/'$command_name'\' \\' '    -d "authToken=$authToken" \\' '    -d \'!\' | jq')"
end
