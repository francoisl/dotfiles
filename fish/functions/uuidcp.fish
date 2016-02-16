function uuidcp --description 'Generate a UUID and copy it to the Clipboard'
    uuidgen | tr -d '\n' | tr '[:upper:]' '[:lower:]' | pbcopy
end
