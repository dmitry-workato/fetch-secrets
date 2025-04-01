# fetch-secrets
Fetch github secrets of a given repository the user has write access to.

## Usage

The 'git', 'curl' and 'jq' utilities are required to run this script.
From the root of cloned github repo run:
```shell
curl -s https://raw.githubusercontent.com/dmitry-workato/fetch-secrets/main/script.sh | bash -s DATABRICKS_PERSONAL_ACCESS_TOKEN
```

On successful run the secrets will be stored in local file 'fetch-gha-secrets-unix_time.txt' in ready to "source" format.
