function end() {
  echo "${@:2}"
  exit "${1}"
}
function error() {
  end 1 "Error: ${*}"
}
function stop() {
  end 0 "Stopping: ${*}"
}

echo "Initialising"
[ -n "${GH_TOKEN}" ] || error "a GH_TOKEN is required"
[ -d "${ITEM}" ] || [ -f "${ITEM}" ] || error "ITEM needs to be a valid file or directory"
[ -n "${REPO}" ] || error "a destination REPO is required"
[ -n "${REPO_OWNER}" ] || error "a destination REPO_OWNER is required"

: "${REPO_BASE_BRANCH="master"}"
: "${REPO_TARGET_DIR="."}"
: "${REPO_TARGET_BRANCH="auto-update/${REPO_BASE_BRANCH}"}"
: "${COMMIT_AUTHOR="Auto Cross Pull Requester"}"
: "${COMMIT_EMAIL="noreply@github.com"}"
: "${COMMIT_MESSAGE="Auto update"}"
: "${PR_TITLE:="Auto Update"}"
: "${PR_BODY:="This is an automatic update."}"

git config --global user.email "${COMMIT_EMAIL}"
git config --global user.name "${COMMIT_AUTHOR}"

echo "Cloning destination repository"
CLONE_DIR=$(mktemp -d)
git clone \
  "https://x-access-token:${GH_TOKEN}@github.com/${REPO_OWNER}/${REPO}.git" \
  "${CLONE_DIR}" || error "could not clone repository"
cp -r "${ITEM}" "${CLONE_DIR}/${REPO_TARGET_DIR}" || error "could not copy item into cloned directory"
cd "${CLONE_DIR}" || error "could not cd into cloned directory"

echo "Switching to branch '${REPO_TARGET_BRANCH}'"
if [ -z "$(git ls-remote --heads origin "${REPO_TARGET_BRANCH}")" ]; then
  echo "Creating new branch"
  git checkout "${REPO_BASE_BRANCH}" || error "could not checkout the base branch"
  git checkout -b "${REPO_TARGET_BRANCH}" || error "could not create target branch"
else
  echo "Checking out existing branch"
  git add . || error "could not add changes to be stashed"
  git stash || error "could not stash changes"
  git checkout "${REPO_TARGET_BRANCH}" || error "could not checkout the target branch"
  git stash pop || error "could not pop stashed changes"
  git reset HEAD . || error "could not reset head after stash pop"
fi

echo "Checking diff"
[ -n "$(git status --porcelain)" ] || stop "no changes detected"

echo "Committing changes"
git add . || error "could not add changes"
git commit -m "${COMMIT_MESSAGE}" || error "could not commit changes"

echo "Pushing changes"
git push origin "${REPO_TARGET_BRANCH}" || error "could not push changes"

echo "Creating Pull Request"
# See https://docs.github.com/en/rest/reference/pulls#create-a-pull-request
read -r -d '' body <<EOF
{
    "head": "${REPO_TARGET_BRANCH}",
    "base": "${REPO_BASE_BRANCH}",
    "title": "${PR_TITLE}",
    "body": "${PR_BODY}"
}
EOF

curl "https://api.github.com/repos/${REPO_OWNER}/${REPO}/pulls" \
  -H "Authorization: token ${GH_TOKEN}" \
  -H 'Content-Type: application/json; charset=utf-8' \
  -H "Accept: application/vnd.github.v3+json" \
  -d "${body}" \
  -w "%{response_code}" \
  -o /dev/null \
  >http.response.code 2>error.messages || error "PR create request failed"

res="$(cat http.response.code)"
case "${res}" in
201) echo "PR created successfully" ;;
422) echo "PR already exists" ;;
*) error "PR create request returned '${res}'" ;;
esac
