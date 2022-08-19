function _load_nvm --on-variable PWD --description 'Auto-switch to the correct nvm version on cd'
    if [ -e .nvmrc ]
        nvm use
    end
end
