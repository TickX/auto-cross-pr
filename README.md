# Auto Cross Pull Requester

A simple GitHub action that, given some file(s), commits any changes and submits a pull request to the target
repository, on the specified branch and directory.

A use case for this is to generate some files (eg. TypeScript definitions) during a build
in one repo (eg. API service), and commit them to another (eg. web app).

## Usage

```yaml
- uses: actions/checkout@v2
- name: Create PR to my-org/target-repo
  uses: TickX/auto-cross-pr@v0.1.0
  with:
    token: ${{ secrets.GH_TOKEN }}
    item: path/to/file.ext
    repo: target-repo
    repo_owner: my-org
```

### Action Inputs

Here's the full list of inputs:

|      **Input**     |                           **Description**                           |            **Default**            |
|:------------------:|:-------------------------------------------------------------------:|:---------------------------------:|
| `token`            | A GitHub access token (see [section](#github-access-token))         |                                   |
| `item`             | The file or directory to commit                                     |                                   |
| `repo`             | The target repository                                               |                                   |
| `repo_owner`       | The target repository owner                                         |                                   |
| `repo_base_branch` | A new branch will be created from this one before submitting the PR | `master`                          |
| `repo_target_dir`  | The chosen item will be committed to this directory                 | `auto-update/${REPO_BASE_BRANCH}` |
| `commit_author`    | The author of the commit                                            | "Auto Cross Pull Requester"       |
| `commit_email`     | The email associated with the commit                                | noreply@github.com                |
| `commit_message`   | The commit message                                                  | "Auto update"                     |
| `pr_title`         | The PR title                                                        | "Auto Update"                     |

### GitHub Access Token

The `token` input requires a scoped Personal Access Token; You can use GitHub's `GITHUB_TOKEN` environment
variable for that. **However**, if you do, PRs created by this action will **not** trigger other `on: [push]`
and `on: [pull_request]` workflows.

For more information about this limitation and its workarounds, see [this action's brilliant documentation](https://github.com/peter-evans/create-pull-request/blob/master/docs/concepts-guidelines.md#triggering-further-workflow-runs).

If you just want a [solid workaround](https://github.com/peter-evans/create-pull-request/blob/master/docs/concepts-guidelines.md#authenticating-with-github-app-generated-tokens),
use a GitHub App for the sole purpose of creating a token:
1. [Create an app](https://docs.github.com/en/developers/apps/creating-a-github-app):
   - This can be minimal; Enter any valid URL value for the `Homepage URL` field, eg. your repo's github pages URL
   `my-org.github.io/my-repo`, and uncheck `Active` under `Webhook`.
   - Under `Repository permissions: Contents` select `Access: Read & write`.
   - Under `Repository permissions: Pull requests` select `Access: Read & write`.
2. Create and download a Private Key from the app's settings page.
3. Install the app on the repositories involved in this action.
4. In your workflow, obtain a token by using [tibdex/github-app-token](https://github.com/tibdex/github-app-token),
which takes your app's ID and private key and generates a temporary auth token.
5. Pass the generated token to this action's `token` input.
