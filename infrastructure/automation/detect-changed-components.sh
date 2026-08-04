#!/usr/bin/env bash
#
# Determines which infrastructure/<component> directories must be deployed
# for the current workflow run, and writes the result as a JSON array to
# GITHUB_OUTPUT (key: components). Runs on the GitHub Actions runner, as
# the "plan" job of .github/workflows/deploy-platform.yml — never on the
# production server.
#
# Selection rules, in order:
#   1. workflow_dispatch with an explicit component input -> that one
#      component only.
#   2. workflow_dispatch with no component input -> every known component
#      (a manual full resync).
#   3. push with no usable "before" SHA (first push seen, or a force-push
#      GitHub reports as all-zeros) -> every known component, since a
#      correct diff base can't be established.
#   4. push with a usable diff range -> every component whose directory
#      changed. A change under infrastructure/compose/ (fragments shared
#      by more than one component's compose.yaml) is treated as a change
#      to every component, since any of them may include it.
#
# infrastructure/automation/ itself is never treated as a deployable
# component — it holds this script and deploy-component.sh, which are
# re-synced to /srv/platform/automation/ on every component deploy
# regardless of whether automation/ changed.
#
# Reference: docs/01-architecture/ARCH-005-deployment-strategy.md
#            docs/03-standards/STD-011-platform-deployment-pipeline-standard.md

set -euo pipefail

INFRA_DIR="infrastructure"
NON_COMPONENT_DIRS=("automation" "compose")

list_components() {
  local dir name skip found
  for dir in "${INFRA_DIR}"/*/; do
    name="$(basename "${dir}")"
    skip=0
    for found in "${NON_COMPONENT_DIRS[@]}"; do
      [ "${name}" = "${found}" ] && skip=1
    done
    [ "${skip}" -eq 0 ] && echo "${name}"
  done
}

all_components="$(list_components)"

select_all() {
  echo "${all_components}"
}

if [ "${EVENT_NAME:-}" = "workflow_dispatch" ] && [ -n "${MANUAL_COMPONENT:-}" ]; then
  if ! grep -qx "${MANUAL_COMPONENT}" <<< "${all_components}"; then
    echo "Unknown component: '${MANUAL_COMPONENT}'." >&2
    echo "Known components: $(tr '\n' ' ' <<< "${all_components}")" >&2
    exit 1
  fi
  selected="${MANUAL_COMPONENT}"
  echo "Manual dispatch for a single component: ${selected}" >&2

elif [ "${EVENT_NAME:-}" = "workflow_dispatch" ]; then
  selected="$(select_all)"
  echo "Manual dispatch with no component specified: full resync of every component." >&2

elif [ -z "${BEFORE_SHA:-}" ] || [ "${BEFORE_SHA}" = "0000000000000000000000000000000000000000" ]; then
  selected="$(select_all)"
  echo "No usable prior commit for a diff (first push or force-push): deploying every component." >&2

else
  changed_paths="$(git diff --name-only "${BEFORE_SHA}" "${AFTER_SHA}" -- "${INFRA_DIR}")"
  if grep -q "^${INFRA_DIR}/compose/" <<< "${changed_paths}"; then
    selected="$(select_all)"
    echo "infrastructure/compose/ (shared fragments) changed: deploying every component." >&2
  else
    changed_dirs="$(awk -F/ -v n=2 '{print $n}' <<< "${changed_paths}" | sort -u)"
    selected="$(comm -12 <(sort <<< "${all_components}") <(sort <<< "${changed_dirs}"))"
    echo "Changed components since ${BEFORE_SHA}: $(tr '\n' ' ' <<< "${selected}")" >&2
  fi
fi

json="$(grep -v '^$' <<< "${selected}" | jq -R . | jq -sc .)"
echo "components=${json}" >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is not set}"
echo "Selected components: ${json}" >&2
