#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

update_self() {
    local BRANCH CurrentBranch
    BRANCH=${1-}
    pushd "${SCRIPTPATH}" &> /dev/null || fatal "Failed to change directory.\nFailing command: ${F[C]}push \"${SCRIPTPATH}\""
    CurrentBranch="$(git branch --show)"
    popd &> /dev/null

    local Title="Update ${APPLICATION_NAME}"
    local Question YesNotice NoNotice
    if [[ -z ${BRANCH-} ]]; then
        if [[ -z ${CurrentBranch-} ]]; then
            error "You need to specify a branch to update to."
            return 1
        fi
        Question="Would you like to update ${APPLICATION_NAME} to current branch ${CurrentBranch} now?"
        NoNotice="${APPLICATION_NAME} will not be updated."
        YesNotice="Updating ${APPLICATION_NAME} to branch ${CurrentBranch}."
    elif [[ ${BRANCH-} == "${CurrentBranch-}" ]]; then
        Question="Would you like to forcefully update ${APPLICATION_NAME} to current branch ${BRANCH} now?"
        NoNotice="${APPLICATION_NAME} will not be updated."
        YesNotice="Updating ${APPLICATION_NAME} to branch ${BRANCH}."
    else
        Question="Would you like to update ${APPLICATION_NAME} from branch ${CurrentBranch} to ${BRANCH} now?"
        NoNotice="${APPLICATION_NAME} will not be updated from branch ${CurrentBranch} to ${BRANCH}."
        YesNotice="Updating ${APPLICATION_NAME} from branch ${CurrentBranch} to ${BRANCH}."
    fi
    if ! run_script 'question_prompt' Y "${Question}" "${Title}" "${FORCE:+Y}"; then
        if use_dialog_box; then
            notice "${NoNotice}" |& dialog_pipe "${DC[TitleError]}${Title}" "${NoNotice}"
        else
            notice "${NoNotice}"
        fi
        return
    fi

    if use_dialog_box; then
        commands_update_self "${BRANCH}" "${YesNotice}" |&
            dialog_pipe "${DC[TitleSuccess]}${Title}" "${YesNotice}\n${DC[CommandLine]} ds --update $*"
    else
        commands_update_self "${BRANCH}" "${YesNotice}"
    fi
}

commands_update_self() {
    local BRANCH=${1-}
    local Notice=${2-}
    local CurrentBranch

    pushd "${SCRIPTPATH}" &> /dev/null || fatal "Failed to change directory.\nFailing command: ${F[C]}push \"${SCRIPTPATH}\""
    if [[ -z ${BRANCH-} ]]; then
        BRANCH="$(git branch --show)"
        if ! ds_update_available; then
            notice "${APPLICATION_NAME} is already up to date on branch ${BRANCH}."
            notice "Current version is $(ds_version)"
            return
        fi
    fi
    local QUIET=''
    if [[ -z ${VERBOSE-} ]]; then
        QUIET='--quiet'
    fi
    if [[ -d ${INSTANCES_FOLDER:?} ]]; then
        notice "Clearing instances folder"
        run_script 'set_permissions' "${INSTANCES_FOLDER:?}"
        rm -fR "${INSTANCES_FOLDER:?}/"* &> /dev/null || fatal "Failed to clear instances folder.\nFailing command: ${F[C]}rm -fR \"${INSTANCES_FOLDER:?}/\"*"
    fi
    notice "${Notice}"
    cd "${SCRIPTPATH}" || fatal "Failed to change directory.\nFailing command: ${F[C]}cd \"${SCRIPTPATH}\""
    info "Setting file ownership on current repository files"
    sudo chown -R "$(id -u)":"$(id -g)" "${SCRIPTPATH}/.git" > /dev/null 2>&1 || true
    sudo chown "$(id -u)":"$(id -g)" "${SCRIPTPATH}" > /dev/null 2>&1 || true
    git ls-tree -rt --name-only HEAD | xargs sudo chown "$(id -u)":"$(id -g)" > /dev/null 2>&1 || true

    info "Fetching recent changes from git."
    eval git fetch ${QUIET-} --all --prune || fatal "Failed to fetch recent changes from git.\nFailing command: ${F[C]}git fetch ${QUIET-} --all --prune"
    if [[ ${CI-} != true ]]; then
        if [[ -n ${BRANCH-} ]]; then
            eval git switch ${QUIET-} --force "${BRANCH}" || fatal "Failed to switch to github branch ${BRANCH}.\nFailing command: ${F[C]}git switch ${QUIET-} --force \"${BRANCH}\""
            eval git reset ${QUIET-} --hard origin/"${BRANCH}" || fatal "Failed to reset to branch origin/${BRANCH}.\nFailing command: ${F[C]}git reset ${QUIET-} --hard origin/\"${BRANCH}\""
        else
            eval git reset ${QUIET-} --hard HEAD || fatal "Failed to reset to current branch.\nFailing command: ${F[C]}git reset ${QUIET-} --hard HEAD"
        fi
        info "Pulling recent changes from git."
        eval git pull ${QUIET-} || fatal "Failed to pull recent changes from git.\nFailing command: ${F[C]}git pull ${QUIET-}"
    fi
    info "Cleaning up unnecessary files and optimizing the local repository."
    eval git gc ${QUIET-} || true
    info "Setting file ownership on new repository files"
    git ls-tree -rt --name-only "${BRANCH}" | xargs sudo chown "${DETECTED_PUID}":"${DETECTED_PGID}" > /dev/null 2>&1 || true
    sudo chown -R "${DETECTED_PUID}":"${DETECTED_PGID}" "${SCRIPTPATH}/.git" > /dev/null 2>&1 || true
    sudo chown "${DETECTED_PUID}":"${DETECTED_PGID}" "${SCRIPTPATH}" > /dev/null 2>&1 || true
    notice "Updated to $(ds_version)"
    popd &> /dev/null
    exec bash "${SCRIPTNAME}" -e
}

test_update_self() {
    run_script 'update_self' "${COMMIT_SHA-}"
}
