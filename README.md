# Github action for AWX and Ansible Tower resource triggering

[![main](https://github.com/fitbeard/action-trigger-awx/workflows/main/badge.svg)](https://github.com/fitbeard/action-trigger-awx/actions?query=workflow%3Amain)

This Github action aims to interact with AWX or Tower servers.

It connects to an AWX or Tower server and launches a job or workflow_job template or updates project.

> **Note**
>
> For best compatibility and if it possible always use the identical version of this action to your installed AWX version.

## Usage

See [action.yml](action.yml)

### Exaples

```yaml
  awx-examples:
    runs-on: ubuntu-latest
    steps:
      - name: "Test AWX: Simple job template"
        uses: fitbeard/action-trigger-awx@v22.0.0
        with:
          tower_url: ${{ secrets.TOWER_HOST }}
          tower_token: ${{ secrets.TOWER_OAUTH_TOKEN }}
          resource_type: job_template
          resource_name: actions-awxkit-test

      - name: "Test AWX: Simple job template - specify credentials"
        uses: fitbeard/action-trigger-awx@v22.0.0
        with:
          tower_url: ${{ secrets.TOWER_HOST }}
          tower_token: ${{ secrets.TOWER_OAUTH_TOKEN }}
          resource_type: job_template
          resource_name: actions-awxkit-test
          credentials: "test-credential"

      - name: "Test AWX: Simple workflow template"
        uses: fitbeard/action-trigger-awx@v22.0.0
        with:
          tower_url: ${{ secrets.TOWER_HOST }}
          tower_token: ${{ secrets.TOWER_OAUTH_TOKEN }}
          resource_type: workflow_job_template
          resource_name: actions-awxkit-workflow-test

      - name: "Test AWX: Project update"
        uses: fitbeard/action-trigger-awx@v22.0.0
        with:
          tower_url: ${{ secrets.TOWER_HOST }}
          tower_token: ${{ secrets.TOWER_OAUTH_TOKEN }}
          resource_type: project
          resource_name: ansible-project

      - name: "Test AWX: Random options job template 1"
        uses: fitbeard/action-trigger-awx@v22.0.0
        with:
          tower_url: ${{ secrets.TOWER_HOST }}
          tower_token: ${{ secrets.TOWER_OAUTH_TOKEN }}
          resource_type: job_template
          resource_name: actions-awxkit-test3
          limit: "localhost-0*"
          extra_vars: '{"test": 1, "test2": "this variable"}'
          timeout: 300

      - name: "Test AWX: Random options job template 2"
        uses: fitbeard/action-trigger-awx@v22.0.0
        with:
          tower_url: ${{ secrets.TOWER_HOST }}
          tower_token: ${{ secrets.TOWER_OAUTH_TOKEN }}
          resource_type: job_template
          resource_name: actions-awxkit-test3
          limit: "localhost-0*"
          extra_vars: '{"test": 1, "test2": "this variable"}'
          branch: "test/awxkit_action_poc"
          inventory: localhost-awxkit-test
          tags: "1,two,o_0"
          skip_tags: "nonsense"

      - name: "Test AWX: Simple job template without waiting"
        uses: fitbeard/action-trigger-awx@v22.0.0
        with:
          tower_url: ${{ secrets.TOWER_HOST }}
          tower_token: ${{ secrets.TOWER_OAUTH_TOKEN }}
          resource_type: job_template
          resource_name: actions-awxkit-test2
          monitor: "false"
```
