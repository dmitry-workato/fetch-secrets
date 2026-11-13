#!/bin/bash -xe

# git, curl and jq must be present in PATH
secrets=$1
if [[ -z "$secrets" ]]
then
  echo "Should provide list of secrets to make available to the job. Example: SEC1,SEC2"
  exit 1
fi

if [[ -z "$GITHUB_TOKEN" ]]
then
  echo "GITHUB_TOKEN environment variable with repository write permissions must be set. Visit: https://github.com/settings/tokens"
  exit 3
fi

if [ ! -f .git/config ]
then
  echo "Must be run from the root folder of the github repository clone."
  exit 4
fi

# Must be run inside of a github repository
github_repo=$(git config --get remote.origin.url)
github_repo=${github_repo#https://*github.com/}
github_repo=${github_repo%".git"}

mkdir -p .github/workflows
time_seconds=$(date +%s)
current_branch=$(git rev-parse --abbrev-ref HEAD)
flow="fetch-gha-secrets-${time_seconds}"

function cleanup() {
  git checkout "$current_branch"
  workflow_run_id=$(curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/${github_repo}/actions/runs\?branch=$flow | jq -r '.workflow_runs[0].id')
  curl -L -X DELETE \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$github_repo/actions/runs/$workflow_run_id || true
  git push -d origin "$flow" || true
  git branch -D "$flow" || true
}

git checkout -b "$flow"
trap cleanup EXIT

IFS=','
for s in $secrets
do
  secrets_yaml="$secrets_yaml      $s: \${{ secrets.$s }}
"
done

cat <<EOF > .github/workflows/${flow}.yaml
on:
  push:
    branches:
    - $flow

jobs:
  fetch-secrets:
    runs-on: ubuntu-latest
    env:
$secrets_yaml
    steps:
     - name: Setup upterm session
       uses: owenthereal/action-upterm@v2
       with:
         limit-access-to-actor: true
         allow-exec: true
         wait-timeout-minutes: 5
EOF
git add .github/workflows/${flow}.yaml
git commit -m "Temporal workflow to enable ssh"
git push --set-upstream origin HEAD

artifact_url="null"
max_retries=1
retry=0
while [[ "$artifact_url" == "null" ]]
do
  artifact_url=$(curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$github_repo/actions/artifacts?name=${flow}&per_page=1" | jq -r '.artifacts[0]["archive_download_url"]')
  if [[ "$artifact_url" == "null" ]]
  then
    retry=$((retry + 1))
    if [[ "$retry" == "$max_retries" ]]
    then
      echo "Giving up ..."
      break 
    fi
    sleep 1
  fi
done

echo "ssh -o 'StrictHostKeyChecking no' km8QNSGwW8BYEmNjYEee@uptermd.upterm.dev env | grep '${secrets//,/\\|}'"
