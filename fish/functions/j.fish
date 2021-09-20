function j --description 'Beautify JSON in clipboard' --argument arg1 arg2
    pbpaste | jsonPretty; and pbcopy
end
