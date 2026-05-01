# Fish completions for `worktime`

# Subcommands (only at the first argument position)
complete -c worktime -f -n __fish_use_subcommand -a day -d 'Report a single day (default: today)'
complete -c worktime -f -n __fish_use_subcommand -a heatmap -d 'Render a calendar heatmap'

# `day` flags
complete -c worktime -f -n '__fish_seen_subcommand_from day' -l all-sessions -d 'Include brief power-nap bursts'

# `heatmap` flags
complete -c worktime -x -n '__fish_seen_subcommand_from heatmap' -l weeks -d 'Number of weeks to show'
complete -c worktime -r -n '__fish_seen_subcommand_from heatmap' -l svg -d 'Write SVG to this path'
