#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

menu_config() {
    if [[ ${CI-} == true ]]; then
        return
    fi

    local Title="Configuration Menu"
    {
        run_script 'env_backup'
        run_script 'appvars_create_all' || true
    } |& dialog_pipe "${DC[TitleSuccess]}Creating environment variables for added apps" "Please be patient, this can take a while.\n${DC[CommandLine]} ds --env" "${DIALOGTIMEOUT}"
    local OptionFullSetup="Full Setup"
    local OptionEditGlobalVars="Edit Global Variables"
    local OptionSelectApps="Select Applications"
    local OptionEditAppVars="Configure Applications"
    local OptionComposeUp="Start All Applications"
    local OptionComposeDown="Stop All Applications"
    local OptionDockerPrune="Prune Docker System"
    local ConfigOpts=(
        "${OptionFullSetup}" "This goes through selecting apps and editing variables. Recommended for first run"
        "${OptionEditGlobalVars}" "Review and adjust global variables"
        "${OptionSelectApps}" "Select which apps to run. Previously installed apps are remembered"
        "${OptionEditAppVars}" "Review and adjust variables for installed apps"
        "${OptionComposeUp}" "Run Docker Compose to start all applications"
        "${OptionComposeDown}" "Run Docker Compose to stop all applications"
        "${OptionDockerPrune}" "Remove all unused containers, networks, volumes, images and build cache"
    )

    local LastConfigChoice=""
    while true; do
        local -a ConfigChoiceDialog=(
            --stdout
            --title "${DC["Title"]}${Title}"
            --ok-label "Select"
            --cancel-label "Back"
            --menu "What would you like to do?" 0 0 0
            "${ConfigOpts[@]}"
        )
        local ConfigChoice
        local -i ConfigDialogButtonPressed=0
        ConfigChoice=$(_dialog_ --default-item "${LastConfigChoice}" "${ConfigChoiceDialog[@]}") || ConfigDialogButtonPressed=$?
        LastConfigChoice=${ConfigChoice}
        case ${DIALOG_BUTTONS[ConfigDialogButtonPressed]-} in
            OK)
                case "${ConfigChoice}" in
                    "${OptionFullSetup}")
                        run_script 'menu_config_vars' || true
                        run_script 'menu_app_select' || true
                        run_script 'menu_config_apps' || true
                        ;;
                    "${OptionEditGlobalVars}")
                        run_script 'menu_config_vars' || true
                        ;;
                    "${OptionSelectApps}")
                        run_script 'menu_app_select' || true
                        ;;
                    "${OptionEditAppVars}")
                        run_script 'menu_config_apps' || true
                        ;;
                    "${OptionComposeUp}")
                        run_script 'docker_compose' "update"
                        ;;
                    "${OptionComposeDown}")
                        run_script 'docker_compose' "down"
                        ;;
                    "${OptionDockerPrune}")
                        run_script 'docker_prune'
                        ;;
                    *)
                        error "Invalid Option"
                        ;;
                esac
                ;;
            CANCEL | ESC)
                return
                ;;
            *)
                if [[ -n ${DIALOG_BUTTONS[ConfigDialogButtonPressed]-} ]]; then
                    fatal "Unexpected dialog button '${DIALOG_BUTTONS[ConfigDialogButtonPressed]}' pressed in menu_config."
                else
                    fatal "Unexpected dialog button value '${ConfigDialogButtonPressed}' pressed in menu_config."
                fi
                ;;
        esac
    done
}

test_menu_config() {
    # run_script 'menu_config'
    warn "CI does not test menu_config."
}
