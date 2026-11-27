#!/bin/bash
# Decide which console images to build, and resolve upstream digest + version tag for each.
#
# Inputs (env):
#   EVENT        github.event_name (workflow_dispatch|schedule|push|pull_request)
#   CONSOLE      workflow_dispatch: console name (e.g. "debian") or "all"
#   NO_CACHE     workflow_dispatch: "true" to build without cache
#   BASE_SHA     push/pull_request: commit to diff against (empty/zeros => build all)
#   HEAD_SHA     push/pull_request: commit being built
#   REPO_PREFIX  image prefix used for update detection (default: docker.io/benok/os-)
#
# Output: JSON array on stdout, one object per console to build:
#   {name, dir, upstream, digest, version, no_cache}
# Logs go to stderr.
set -euo pipefail

cd "$(dirname "$0")/../.."

REPO_PREFIX=${REPO_PREFIX:-docker.io/benok/os-}
DATE=$(date -u +%Y%m%d)

log() { echo "$@" >&2; }

all_dirs() { ls -d images/10-*console | sed 's|^images/||'; }
console_name() { echo "$1" | sed -E 's/^[0-9]+-(.*)console$/\1/'; }

# --- select candidate consoles -------------------------------------------
NO_CACHE_FLAG=false
case "${EVENT}" in
  workflow_dispatch)
    [ "${NO_CACHE:-false}" = "true" ] && NO_CACHE_FLAG=true
    if [ "${CONSOLE:-all}" = "all" ]; then
      dirs=$(all_dirs)
    else
      dirs="10-${CONSOLE}console"
      [ -d "images/${dirs}" ] || { log "unknown console: ${CONSOLE}"; exit 1; }
    fi
    ;;
  schedule)
    # rebuilt only when upstream moved; never reuse cache so package upgrades are fresh
    NO_CACHE_FLAG=true
    dirs=$(all_dirs)
    ;;
  push|pull_request)
    if [ -z "${BASE_SHA:-}" ] || [[ "${BASE_SHA}" =~ ^0+$ ]] \
        || ! changed=$(git diff --name-only "${BASE_SHA}" "${HEAD_SHA}" 2>/dev/null); then
      log "no usable base commit, building all"
      dirs=$(all_dirs)
    elif echo "${changed}" | grep -qE '^(images/02-console/|\.github/)'; then
      log "shared files changed, building all"
      dirs=$(all_dirs)
    else
      dirs=$(echo "${changed}" | sed -nE 's|^images/(10-[^/]*console)/.*|\1|p' | sort -u)
      dirs=$(for d in ${dirs}; do [ -d "images/${d}" ] && echo "${d}"; done)
    fi
    ;;
  *)
    log "unsupported event: ${EVENT}"; exit 1 ;;
esac

# --- helpers ---------------------------------------------------------------
# index digest of an image reference
digest_of() {
  docker buildx imagetools inspect "$1" --format '{{json .Manifest}}' | jq -r .digest
}

# base digest recorded on our published image ("" if none)
published_base_digest() {
  docker buildx imagetools inspect "$1" --format '{{json .Image}}' 2>/dev/null \
    | jq -r 'if has("config") then . else (.["linux/amd64"] // first(.[])) end
             | .config.Labels["org.opencontainers.image.base.digest"] // ""' 2>/dev/null \
    || true
}

# pick the most specific upstream tag sharing the digest:
#   dated (trixie-20261123, noble-20261110.1) > x.y.z (3.24.4) > N-<date> (fedora 45) > <tag>-<date>
version_of() {
  local repo=$1 tag=$2 digest=$3 ns=library name tags
  if [[ "${repo}" == */* ]]; then ns=${repo%%/*}; name=${repo#*/}; else name=${repo}; fi
  tags=$(curl -fsSL "https://hub.docker.com/v2/repositories/${ns}/${name}/tags?page_size=100&ordering=last_updated" \
    | jq -r --arg d "${digest}" '.results[] | select(.digest == $d) | .name') || tags=""
  local t
  t=$(echo "${tags}" | grep -E '^[a-z]+-[0-9]{8}(\.[0-9]+)?$' | sort -V | tail -n 1 || true)
  [ -n "${t}" ] && { echo "${t}"; return; }
  t=$(echo "${tags}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)
  [ -n "${t}" ] && { echo "${t}"; return; }
  t=$(echo "${tags}" | grep -E '^[0-9]+$' | sort -V | tail -n 1 || true)
  [ -n "${t}" ] && { echo "${t}-${DATE}"; return; }
  echo "$(echo "${tag}" | tr -c 'A-Za-z0-9._\n-' '_')-${DATE}"
}

# --- resolve each console ----------------------------------------------------
result='[]'
for dir in ${dirs}; do
  name=$(console_name "${dir}")
  upstream=$(sed -nE 's/^FROM[[:space:]]+([^[:space:]]+).*/\1/p' "images/${dir}/Dockerfile" | head -n 1)
  repo=${upstream%%:*}
  tag=${upstream#*:}; [ "${tag}" = "${upstream}" ] && tag=latest
  digest=$(digest_of "${upstream}")

  if [ "${EVENT}" = "schedule" ]; then
    current=$(published_base_digest "${REPO_PREFIX}${name}console:latest")
    if [ "${current}" = "${digest}" ]; then
      log "${name}: ${upstream} unchanged (${digest}), skip"
      continue
    fi
    log "${name}: ${upstream} changed (${current:-none} -> ${digest})"
  fi

  version=$(version_of "${repo}" "${tag}" "${digest}")
  log "${name}: ${upstream}@${digest} => ${version}"

  result=$(jq -c --arg name "${name}" --arg dir "${dir}" --arg upstream "${upstream}" \
    --arg digest "${digest}" --arg version "${version}" --argjson no_cache "${NO_CACHE_FLAG}" \
    '. + [{name: $name, dir: $dir, upstream: $upstream, digest: $digest, version: $version, no_cache: $no_cache}]' \
    <<< "${result}")
done

echo "${result}"
