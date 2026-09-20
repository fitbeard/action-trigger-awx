# GitHub Action for AWX / Ansible Automation Platform Controller

This GitHub Action connects to an AWX or Ansible Automation Platform (AAP)
Controller server and launches a **job template** or **workflow job template**,
or updates a **project** or **inventory source** — optionally waiting for the
run to finish and exposing the launched job id.

It also runs on GitLab CI and via a plain `docker run`; see
[Other environments](#other-environments) at the end.

## Usage

See [action.yml](action.yml).

### Inputs

| Input                    | Required | Default | Description                                                                 |
| ------------------------ | :------: | ------- | --------------------------------------------------------------------------- |
| `controller_host`        |   yes    | —       | AWX / Controller URL.                                                        |
| `controller_oauth_token` |  one of  | —       | OAuth2 token. Provide this **or** `controller_username` + `controller_password`. Takes precedence. |
| `controller_username`    |  one of  | —       | Username. Requires `controller_password`.                                   |
| `controller_password`    |  one of  | —       | Password. Requires `controller_username`.                                   |
| `awxkit_force_basic_auth`|    no    | —       | `true` uses HTTP Basic auth instead of session login for username/password. Required for AAP 2.5+ behind the gateway. |
| `resource_type`          |   yes    | —       | One of `job_template`, `workflow_job_template`, `project`, `inventory_source`. |
| `resource_name`          |   yes    | —       | Name or id of the resource to trigger.                                       |
| `controller_verify_ssl`  |    no    | `true`  | `true` / `false` — verify the controller's TLS certificate.                 |
| `awxkit_api_base_path`   |    no    | —       | Controller API prefix. Leave unset for AWX / standalone controller (awxkit default `/api/`). Set to `/api/controller/` for AAP 2.5+ behind the gateway. |
| `monitor`                |    no    | `true`  | `true` waits for completion (streams output); `false` returns immediately.   |
| `timeout`                |    no    | `3600`  | Max seconds to wait for the job — a positive integer (passed as `--action-timeout`). `0` is rejected, since awxkit would treat it as "no timeout" (unbounded wait). |
| `job_type`               |    no    | —       | `run` or `check` (job templates).                                           |
| `limit`                  |    no    | —       | Host pattern to limit the run.                                              |
| `inventory`              |    no    | —       | Inventory name or id.                                                       |
| `credentials`            |    no    | —       | Credential name or id.                                                      |
| `branch`                 |    no    | —       | SCM branch override (`--scm_branch`).                                       |
| `tags`                   |    no    | —       | Comma-separated job tags to include.                                        |
| `skip_tags`              |    no    | —       | Comma-separated job tags to skip.                                           |
| `extra_vars`             |    no    | —       | Extra variables as JSON, e.g. `{"key": "value"}`.                           |

> **Note**
>
> Launch-time inputs (`limit`, `extra_vars`, `job_tags`, `skip_tags`,
> `job_type`, `inventory`, `credentials`, `branch`) are only accepted when the
> matching field has **Prompt on launch** enabled on the template, and are not
> accepted at all for `project` / `inventory_source` updates. Passing one
> otherwise fails with awxkit's `unrecognized arguments` error.

### Outputs

| Output   | Description                                        |
| -------- | -------------------------------------------------- |
| `job_id` | Id of the launched AWX job / update.               |

### Examples

```yaml
  awx-examples:
    runs-on: ubuntu-latest
    steps:
      - name: "Simple job template (capture the job id for the next step)"
        uses: fitbeard/action-trigger-awx@v26.0.0
        id: example_id
        with:
          controller_host: ${{ secrets.CONTROLLER_HOST }}
          controller_oauth_token: ${{ secrets.CONTROLLER_OAUTH_TOKEN }}
          resource_type: job_template
          resource_name: actions-awxkit-test

      - name: "Use the AWX job id"
        run: echo "${{ steps.example_id.outputs.job_id }}"

      - name: "Job template - specify credentials"
        uses: fitbeard/action-trigger-awx@v26.0.0
        with:
          controller_host: ${{ secrets.CONTROLLER_HOST }}
          controller_oauth_token: ${{ secrets.CONTROLLER_OAUTH_TOKEN }}
          resource_type: job_template
          resource_name: actions-awxkit-test
          credentials: "test-credential"

      - name: "Workflow job template"
        uses: fitbeard/action-trigger-awx@v26.0.0
        with:
          controller_host: ${{ secrets.CONTROLLER_HOST }}
          controller_oauth_token: ${{ secrets.CONTROLLER_OAUTH_TOKEN }}
          resource_type: workflow_job_template
          resource_name: actions-awxkit-workflow-test

      - name: "Project update"
        uses: fitbeard/action-trigger-awx@v26.0.0
        with:
          controller_host: ${{ secrets.CONTROLLER_HOST }}
          controller_oauth_token: ${{ secrets.CONTROLLER_OAUTH_TOKEN }}
          resource_type: project
          resource_name: ansible-project

      - name: "Inventory source update"
        uses: fitbeard/action-trigger-awx@v26.0.0
        with:
          controller_host: ${{ secrets.CONTROLLER_HOST }}
          controller_oauth_token: ${{ secrets.CONTROLLER_OAUTH_TOKEN }}
          resource_type: inventory_source
          resource_name: inventory-source-name

      - name: "Job template with extra options"
        uses: fitbeard/action-trigger-awx@v26.0.0
        with:
          controller_host: ${{ secrets.CONTROLLER_HOST }}
          controller_oauth_token: ${{ secrets.CONTROLLER_OAUTH_TOKEN }}
          resource_type: job_template
          resource_name: actions-awxkit-test3
          limit: "localhost-0*"
          extra_vars: '{"test": 1, "test2": "this variable"}'
          branch: "test/awxkit_action_poc"
          inventory: localhost-awxkit-test
          tags: "1,two,o_0"
          skip_tags: "nonsense"
          timeout: 300

      - name: "Fire-and-forget (do not wait for the job)"
        uses: fitbeard/action-trigger-awx@v26.0.0
        with:
          controller_host: ${{ secrets.CONTROLLER_HOST }}
          controller_oauth_token: ${{ secrets.CONTROLLER_OAUTH_TOKEN }}
          resource_type: job_template
          resource_name: actions-awxkit-test2
          monitor: "false"

      - name: "AAP 2.5+ behind the gateway"
        uses: fitbeard/action-trigger-awx@v26.0.0
        with:
          controller_host: ${{ secrets.CONTROLLER_HOST }}
          controller_oauth_token: ${{ secrets.CONTROLLER_OAUTH_TOKEN }}
          resource_type: job_template
          resource_name: actions-awxkit-test
          awxkit_api_base_path: /api/controller/
```

## Other environments

The same image works outside GitHub Actions. The entrypoint detects the
environment and exposes the launched job id accordingly:

| Environment      | Detected via     | Job id exposed as                                  |
| ---------------- | ---------------- | -------------------------------------------------- |
| GitHub Actions   | `GITHUB_ACTIONS` | `job_id` in `$GITHUB_OUTPUT` (step output)         |
| GitLab CI        | `GITLAB_CI`      | `AWX_JOB_ID` in `awx.env` (dotenv report artifact) |
| Local / other    | —                | `AWX_JOB_ID=<id>` printed to stdout                |

### GitLab CI

Inputs are passed as uppercase environment variables (same names as the action
inputs, e.g. `RESOURCE_TYPE`), and the job id is written to `awx.env` for use as
a [`dotenv` report](https://docs.gitlab.com/ee/ci/yaml/artifacts_reports.html#artifactsreportsdotenv):

```yaml
deploy:awxkit:
  stage: deploy
  image: docker.io/t42x/awxkit:latest
  variables:
    CONTROLLER_HOST: $CONTROLLER_HOST
    CONTROLLER_OAUTH_TOKEN: $CONTROLLER_OAUTH_TOKEN
    RESOURCE_TYPE: job_template
    RESOURCE_NAME: actions-awxkit-test
    # AWXKIT_API_BASE_PATH: /api/controller/   # AAP 2.5+ behind the gateway
  script:
    - awx-ci
  artifacts:
    reports:
      dotenv: awx.env # awx-ci writes AWX_JOB_ID=xxx to awx.env
```

### Local run with Docker

```bash
docker run --rm \
  -e CONTROLLER_HOST="https://awx.example.com" \
  -e CONTROLLER_OAUTH_TOKEN="$CONTROLLER_OAUTH_TOKEN" \
  -e RESOURCE_TYPE=job_template \
  -e RESOURCE_NAME=actions-awxkit-test \
  <image>
# prints: AWX_JOB_ID=<id>
```
