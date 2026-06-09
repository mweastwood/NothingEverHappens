#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Print usage instructions
usage() {
  echo "Usage: $0 [--major | --minor | --patch] [--dry-run]"
  echo "Increments the version tag on git main and pushes it."
  echo ""
  echo "Options:"
  echo "  --major     Increments the major version (e.g. v1.0.9 -> v2.0.0)"
  echo "  --minor     Increments the minor version (e.g. v1.0.9 -> v1.1.0)"
  echo "  --patch     Increments the patch version (e.g. v1.0.9 -> v1.0.10)"
  echo "  --dry-run   Preview the new version tag and target commit without creating/pushing it"
  exit 1
}

# Parse options
INCREMENT_TYPE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --major)
      if [ -n "$INCREMENT_TYPE" ]; then
        echo "Error: Only one increment flag can be specified." >&2
        usage
      fi
      INCREMENT_TYPE="major"
      shift
      ;;
    --minor)
      if [ -n "$INCREMENT_TYPE" ]; then
        echo "Error: Only one increment flag can be specified." >&2
        usage
      fi
      INCREMENT_TYPE="minor"
      shift
      ;;
    --patch)
      if [ -n "$INCREMENT_TYPE" ]; then
        echo "Error: Only one increment flag can be specified." >&2
        usage
      fi
      INCREMENT_TYPE="patch"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: Unknown option $1" >&2
      usage
      ;;
  esac
done

if [ -z "$INCREMENT_TYPE" ]; then
  echo "Error: Increment type is required (--major, --minor, or --patch)." >&2
  usage
fi

# Ensure we are in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Not in a git repository." >&2
  exit 1
fi

# Determine the git remote (default to origin if exists, otherwise first available remote)
REMOTE="origin"
if ! git remote | grep -q "^$REMOTE$"; then
  REMOTE=$(git remote | head -n 1)
fi

# Fetch the latest main branch and update local main if a remote exists
if [ -n "$REMOTE" ]; then
  CURRENT_BRANCH=$(git branch --show-current)
  if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "Fetching and merging latest main from $REMOTE..."
    git fetch "$REMOTE" main
    if ! git merge --ff-only FETCH_HEAD; then
      echo "Error: Local 'main' has diverged from '$REMOTE/main' and cannot be fast-forwarded." >&2
      echo "Please resolve this manually before running the script." >&2
      exit 1
    fi
  else
    echo "Fetching latest main from $REMOTE..."
    if git show-ref --verify --quiet refs/heads/main; then
      if ! git fetch "$REMOTE" main:main; then
        echo "Error: Local 'main' has diverged from '$REMOTE/main' and cannot be fast-forwarded." >&2
        echo "Please check out 'main' and resolve the differences." >&2
        exit 1
      fi
    else
      # Local main branch doesn't exist yet, fetch it directly
      git fetch "$REMOTE" main:main
    fi
  fi
fi

# Get the last version tag on main branch matching v*
LAST_TAG=$(git describe --tags --match "v*" --abbrev=0 main 2>/dev/null || true)

if [ -z "$LAST_TAG" ]; then
  echo "No version tag (matching 'v*') found on main branch history. Starting from v0.0.0."
  LAST_TAG="v0.0.0"
else
  echo "Found last version tag: $LAST_TAG"
fi

# Parse version components
VERSION="${LAST_TAG#v}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Tag '$LAST_TAG' does not follow semantic versioning (vMAJOR.MINOR.PATCH)." >&2
  exit 1
fi

IFS='.' read -r major minor patch <<< "$VERSION"

# Increment version based on flag
case "$INCREMENT_TYPE" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
esac

NEW_TAG="v${major}.${minor}.${patch}"
echo "Incrementing to new tag: $NEW_TAG"

# Check if the tag already exists in the repository
if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
  echo "Error: Tag '$NEW_TAG' already exists in the repository." >&2
  exit 1
fi

# Get the latest commit on main branch
LATEST_MAIN_COMMIT=$(git rev-parse main 2>/dev/null || true)
if [ -z "$LATEST_MAIN_COMMIT" ]; then
  echo "Error: Branch 'main' not found." >&2
  exit 1
fi

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] Would create signed tag $NEW_TAG on commit $LATEST_MAIN_COMMIT (tip of main)."
  if [ -n "$REMOTE" ]; then
    echo "[DRY RUN] Would push tag $NEW_TAG to $REMOTE."
  else
    echo "[DRY RUN] No remote found to push to."
  fi
else
  # Print the target commit info
  echo "Tagging commit $LATEST_MAIN_COMMIT on main..."

  # Create the signed tag
  git tag -s "$NEW_TAG" -m "$NEW_TAG" "$LATEST_MAIN_COMMIT"

  if [ -z "$REMOTE" ]; then
    echo "Warning: No git remote found. Skipping push of tag."
  else
    echo "Pushing tag $NEW_TAG to $REMOTE..."
    git push "$REMOTE" "$NEW_TAG"
  fi

  echo "Successfully tagged and pushed $NEW_TAG!"
fi
