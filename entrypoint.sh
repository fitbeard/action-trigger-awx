#! /usr/bin/env bash

set -e

export PYTHONUNBUFFERED=1

# --- Required connection settings (consumed by awxkit from the environment) ---

if [ -z "$CONTROLLER_HOST" ]; then
  echo "Controller host is not set. Exiting."
  exit 1
fi

# Authentication: provide either an OAuth2 token, or a username + password.
# awxkit reads CONTROLLER_OAUTH_TOKEN, CONTROLLER_USERNAME, CONTROLLER_PASSWORD
# and AWXKIT_FORCE_BASIC_AUTH directly from the environment (the awx subprocess
# inherits them). Token takes precedence over username/password. For AAP 2.5+
# behind the gateway, username/password auth requires AWXKIT_FORCE_BASIC_AUTH=true.
if [ -z "$CONTROLLER_OAUTH_TOKEN" ] && { [ -z "$CONTROLLER_USERNAME" ] || [ -z "$CONTROLLER_PASSWORD" ]; }; then
  echo "No authentication provided. Set CONTROLLER_OAUTH_TOKEN, or both CONTROLLER_USERNAME and CONTROLLER_PASSWORD. Exiting."
  exit 1
fi

if [ -z "$CONTROLLER_VERIFY_SSL" ]; then
  CONTROLLER_VERIFY_SSL="true"
elif [ "$CONTROLLER_VERIFY_SSL" = "true" ]; then
  CONTROLLER_VERIFY_SSL="true"
elif [ "$CONTROLLER_VERIFY_SSL" = "false" ]; then
  CONTROLLER_VERIFY_SSL="false"
else
  echo "Unknown ssl verify value. Exiting."
  exit 1
fi
# awxkit reads CONTROLLER_VERIFY_SSL directly from the environment.
export CONTROLLER_VERIFY_SSL

# Optional controller API path override. awxkit's own default is /api/, which is
# correct for AWX and standalone controllers. Ansible Automation Platform 2.5+
# serves the controller API behind the gateway at /api/controller/, so those
# users must opt in by setting AWXKIT_API_BASE_PATH=/api/controller/. We only
# touch the environment when a value is provided, to avoid changing behaviour for
# existing AWX users.
if [ -n "$AWXKIT_API_BASE_PATH" ]; then
  export AWXKIT_API_BASE_PATH
else
  # Empty or unset: let awxkit use its own default (/api/).
  unset AWXKIT_API_BASE_PATH
fi

# --- Required resource selection ---

if [ -z "$RESOURCE_TYPE" ]; then
  echo "Resource type is not set. Exiting."
  exit 1
fi

if [ -z "$RESOURCE_NAME" ]; then
  echo "Resource name or id is not set. Exiting."
  exit 1
fi

# Map the resource type to its awx subcommand.
case "$RESOURCE_TYPE" in
  job_template)          AWX_ARGS=(job_templates launch) ;;
  workflow_job_template) AWX_ARGS=(workflow_job_templates launch) ;;
  project)               AWX_ARGS=(projects update) ;;
  inventory_source)      AWX_ARGS=(inventory_sources update) ;;
  *)
    echo "Unknown resource type. Exiting."
    exit 1
    ;;
esac

# The resource name/id is the positional argument, followed by the fixed
# output format that lets us extract the launched job id from the last line.
AWX_ARGS+=("$RESOURCE_NAME" -f jq --filter .id)

# --- Monitor (wait for completion) ---

if [ -z "$MONITOR" ]; then
  MONITOR="true"
fi

case "$MONITOR" in
  true)  AWX_ARGS+=(--monitor) ;;
  false) ;;
  *)
    echo "Unknown monitor value. Exiting."
    exit 1
    ;;
esac

# --- Timeout (always passed; defaults to one hour) ---
# Must be a positive integer: awxkit treats --action-timeout 0 as "no timeout",
# which silently turns --monitor into an unbounded wait, and a non-numeric value
# would fail later inside awx. Catch both here with a clear message.

if [ -z "$TIMEOUT" ]; then
  TIMEOUT="3600"
elif ! [ "$TIMEOUT" -gt 0 ] 2>/dev/null; then
  echo "TIMEOUT must be a positive integer number of seconds. Got: '$TIMEOUT'. Exiting."
  exit 1
fi
AWX_ARGS+=(--action-timeout "$TIMEOUT")

# --- Optional arguments ---

if [ -n "$LIMIT" ]; then
  AWX_ARGS+=(--limit "$LIMIT")
fi

if [ -n "$INVENTORY" ]; then
  AWX_ARGS+=(--inventory "$INVENTORY")
fi

if [ -n "$CREDENTIALS" ]; then
  AWX_ARGS+=(--credentials "$CREDENTIALS")
fi

if [ -n "$EXTRA_VARS" ]; then
  AWX_ARGS+=(--extra_vars "$EXTRA_VARS")
fi

if [ -n "$BRANCH" ]; then
  AWX_ARGS+=(--scm_branch "$BRANCH")
fi

if [ -n "$TAGS" ]; then
  AWX_ARGS+=(--job_tags "$TAGS")
fi

if [ -n "$SKIP_TAGS" ]; then
  AWX_ARGS+=(--skip_tags "$SKIP_TAGS")
fi

if [ -n "$JOB_TYPE" ]; then
  case "$JOB_TYPE" in
    run|check) AWX_ARGS+=(--job_type "$JOB_TYPE") ;;
    *)
      echo "Unknown job type. Exiting."
      exit 1
      ;;
  esac
fi

# --- Run ---
# Execute awx directly with a quoted argument array so that values containing
# spaces or quotes cannot break out of the command (no eval / no `| bash`).

echo "Running: awx ${AWX_ARGS[*]}"

set +e
awx "${AWX_ARGS[@]}" | tee awxkit-output.log
awx_exit_code=${PIPESTATUS[0]}
set -e

if [ "$awx_exit_code" -ne 0 ]; then
  echo "AWX command failed with exit code $awx_exit_code" >&2
  exit "$awx_exit_code"
fi

# The launched job id is the last non-empty line of awx's output (printed after
# any monitor stream). Strip trailing whitespace and blank lines, take the last.
JOB_ID="$(sed -e 's/[[:space:]]*$//' awxkit-output.log | awk 'NF' | tail -n 1)"

# Expose the job id in whichever environment we are running in.
if [ -n "$GITHUB_ACTIONS" ]; then
  # GitHub Actions: expose as a step output (use steps.<id>.outputs.job_id).
  echo "job_id=$JOB_ID" >> "$GITHUB_OUTPUT"
elif [ -n "$GITLAB_CI" ]; then
  # GitLab CI: expose as a dotenv report artifact for downstream jobs.
  echo "AWX_JOB_ID=$JOB_ID" >> awx.env
else
  # Local 'docker run' (or any other environment): just print the id.
  echo "AWX_JOB_ID=$JOB_ID"
fi
