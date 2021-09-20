function j --description 'Beautify JSON in clipboard'
    pbpaste | jsonPretty >/dev/null; and pbpaste | jsonPretty | pbcopy
end
