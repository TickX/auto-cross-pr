set -Eeuo pipefail
trap log_err ERR

# Logs any trapped errors.
log_err() {
  printf >&2 "%s failed: '%s' exited with %d on line %d\n" \
    "${FUNCNAME[1]}" "${BASH_COMMAND}" "$?" "${BASH_LINENO[0]}"
}

# Runs the main program.
main() { init; clone; diff; push; }

# Validates and initialises the variables required
# for the script to run.
init() {
  echo "Initialising"
  : "${GH_TOKEN:?'a GH_TOKEN is required'}"
  : "${ITEM:?'a target ITEM is required'}"
  : "${REPO:?'a destionation REPO is required'}"
  : "${REPO_OWNER:?'a destionation REPO_OWNER is required'}"

  : "${REPO_BASE_BRANCH:='master'}"
  : "${REPO_TARGET_DIR:='.'}"
  : "${REPO_TARGET_BRANCH:="auto-update/${REPO_BASE_BRANCH}"}"
  : "${COMMIT_AUTHOR:='Auto Cross Pull Requester'}"
  : "${COMMIT_EMAIL:='noreply@github.com'}"
  : "${COMMIT_MESSAGE:='Auto update'}"
  : "${PR_TITLE:='Auto Update'}"
  : "${PR_BODY:='This is an automatic update.'}"
}

# Clones the target Git repository and adds the target
# files to the target branch.
clone() {
  if [[ ! -d "${ITEM}" ]] && [[ ! -f "${ITEM}" ]]; then
    echo >&2 'ITEM must be a valid file or directory'
    return 1
  fi

  local clone_dir; clone_dir=$(mktemp -d)
  local new_item; new_item="${REPO_TARGET_DIR}/$(basename "${ITEM}")"
  local -r url="https://x-access-token:${GH_TOKEN}@github.com/${REPO_OWNER}/${REPO}.git"

  echo 'Cloning destination repository'
  git clone "${url}" "${clone_dir}"
  cp -r "${ITEM}" "${clone_dir}/${new_item}"
  cd "${clone_dir}"

  echo "Switching to branch '${REPO_TARGET_BRANCH}'"
  if [[ -z "$(git ls-remote --heads origin "${REPO_TARGET_BRANCH}")" ]]; then
    echo 'Creating new branch'
    git checkout "${REPO_BASE_BRANCH}"
    git checkout -b "${REPO_TARGET_BRANCH}"
    return
  fi

  echo 'Checking out existing branch'
  git add .
  git stash
  git checkout "${REPO_TARGET_BRANCH}"
  # Always prioritise and overwrite incoming updates
  # to avoid merge conflicts.
  git checkout stash -- "${new_item}"
}

# Checks the target branch diff.
diff() {
  echo 'Checking diff'
  if [[ -n "$(git status --porcelain)" ]]; then
    echo 'No changes detected.'
    return 1
  fi
}

# Commits and pushes the new changes to the remote
# repository, and creates a PR (if one does not exist).
push() {
  git config --global user.email "${COMMIT_EMAIL}"
  git config --global user.name "${COMMIT_AUTHOR}"

  echo 'Committing changes'
  git add .
  git commit -m "${COMMIT_MESSAGE}"

  echo 'Pushing changes'
  git push origin "${REPO_TARGET_BRANCH}"
 
  echo 'Creating Pull Request'
  local -i res; res="$(
    # See https://docs.github.com/en/rest/reference/pulls#create-a-pull-request
    curl -s "https://api.github.com/repos/${REPO_OWNER}/${REPO}/pulls" \
      -H "Authorization: token ${GH_TOKEN}" \
      -H 'Content-Type: application/json; charset=utf-8' \
      -H 'Accept: application/vnd.github.v3+json' \
      -w '%{response_code}' \
      -o /dev/null \
      -d @- <<- EOF
	{
		"head": "${REPO_TARGET_BRANCH}",
		"base": "${REPO_BASE_BRANCH}",
		"title": "${PR_TITLE}",
		"body": "${PR_BODY}"
	}
	EOF
  )"

  case "${res}" in
    201) echo 'PR created successfully' ;;
    422) echo 'PR already exists' ;;
    *)
      echo >&2 "PR create request returned '${res}'"
      return 1
      ;;
  esac
}

main "$@"
