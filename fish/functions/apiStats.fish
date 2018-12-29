function apiStats --description="Clean up and prettify API stats logs"
    pbpaste | sed -E -e "s/2[0-9]{3}-[0-9]{2}-[0-9]{2}T.*@[a-z0-9]*\.[a-z\.]{2,10})\ //g" | tr -d '[:blank:]\n' | jsonPretty
end
