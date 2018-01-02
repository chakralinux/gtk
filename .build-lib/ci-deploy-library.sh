# ci-depoly-library depends on ci-library

UPLOAD_LIST=()

# Execute command and stop execution if the command fails
function _do_deploy() {
    CMD=$@
    _log command "$CMD"
    $CMD || { _log failure "FAILED: $CMD"; _unlock_repo; exit 1; }
    return $?
}

function _do_akbm() {
    local output
    CMD=$@
    _log command "$CMD"
    output=$($CMD)

    if ! [[ "$output" == *"::SUCCESS::"* ]]; then
        _log failure "FAILED: $CMD output: $output"
        _unlock_repo
        exit 1
    fi
    return $?
}

# performs a remote lock over a repository
function _lock_repo() {
  _do_akbm ssh $SSH_USER@$DEPLOY_SERVER -p $SSH_PORT "akbm --repo-name $DEPLOY_REPO --arch x86_64 --lock"
}

# performs a remote unlock over a repository
function _unlock_repo() {
  _do_akbm ssh $SSH_USER@$DEPLOY_SERVER -p $SSH_PORT "akbm --repo-name $DEPLOY_REPO --arch x86_64 --unlock"
}

function _upload_files() {
  local -a files=( $* )   # files to upload

  rsync -rltoDvh \
    --omit-dir-times  \
    --numeric-ids \
    --progress \
    --delay-updates \
    -e "ssh -p $SSH_PORT" \
    "${files[@]}" $SSH_USER@$DEPLOY_SERVER:/srv/www/rsync.chakralinux.org/packages/$DEPLOY_REPO/x86_64/
}

function upload_files() {
    _log build_step "Start uploading to $DEPLOY_REPO the following packages: ${UPLOAD_LIST[@]}"
    _do _lock_repo
    _do_deploy _upload_files "${UPLOAD_LIST[@]}"
    _do _unlock_repo
    _log success "rsync upload done"
}

function update_remote_db() {
    _log build_step "Start importing pkgs with akbm"
    local -a file_names=( ${UPLOAD_LIST[@]##*/} )

    _do _lock_repo
    # we can no tuse _do in this case, because we have to parse the output to know if was successfully executed
    _do_akbm ssh "$SSH_USER@$DEPLOY_SERVER" -p "$SSH_PORT" "akbm --repo-name $DEPLOY_REPO --arch x86_64 --repo-add" "${file_names[@]}"
    _do _unlock_repo
}

_ensure-var "DEPLOY_REPO"
_ensure-var "DEPLOY_SERVER"
_ensure-var "SSH_USER"
_ensure-var "SSH_PORT"
