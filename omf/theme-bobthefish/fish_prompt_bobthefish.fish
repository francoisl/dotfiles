# Defined in /Users/francois/.config/fish/functions/fish_prompt.fish @ line 1105
function fish_prompt --description 'bobthefish, a fish theme optimized for awesome'
    # Save the last status for later (do this before anything else)
    set -l last_status $status

    # Use a simple prompt on dumb terminals.
    if [ "$TERM" = 'dumb' ]
        echo '> '
        return
    end

    __bobthefish_glyphs
    __bobthefish_colors $theme_color_scheme

    type -q bobthefish_colors
    and bobthefish_colors

    # Start each line with a blank slate
    set -l __bobthefish_current_bg

    # Status flags and input mode
    __bobthefish_prompt_status $last_status

    # User / hostname info
    __bobthefish_prompt_user

    # Containers and VMs
    __bobthefish_prompt_vagrant
    __bobthefish_prompt_docker
    __bobthefish_prompt_k8s_context

    # Cloud Tools
    __bobthefish_prompt_aws_vault_profile

    # Virtual environments
    __bobthefish_prompt_nix
    __bobthefish_prompt_desk
    __bobthefish_prompt_rubies
    __bobthefish_prompt_virtualfish
    __bobthefish_prompt_virtualgo
    __bobthefish_prompt_node

    set -l real_pwd (__bobthefish_pwd)

    # VCS
    set -l git_root_dir (__bobthefish_git_project_dir $real_pwd)
    set -l hg_root_dir (__bobthefish_hg_project_dir $real_pwd)

    if [ "$git_root_dir" -a "$hg_root_dir" ]
        # only show the closest parent
        switch $git_root_dir
            case $hg_root_dir\*
                __bobthefish_prompt_git $git_root_dir $real_pwd
            case \*
                __bobthefish_prompt_hg $hg_root_dir $real_pwd
        end
    else if [ "$git_root_dir" ]
        __bobthefish_prompt_git $git_root_dir $real_pwd
    else if [ "$hg_root_dir" ]
        __bobthefish_prompt_hg $hg_root_dir $real_pwd
    else
        __bobthefish_prompt_dir $real_pwd
    end

    __bobthefish_finish_segments
end
