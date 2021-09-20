function j --description 'Beautify JSON in clipboard'
    pbpaste | jsonPretty; and pbpaste | jsonPretty | pbcopy
end
