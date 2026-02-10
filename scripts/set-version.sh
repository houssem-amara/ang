#!/bin/bash
# Version management script for GitHub Actions
# Generates semantic version numbers based on branch and commit information

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get branch name from GitHub Actions environment or git
BRANCH_NAME="${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD)}"
print_info "Branch: ${BRANCH_NAME}"

# Get commit SHA (short)
COMMIT_SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"
SHORT_SHA="${COMMIT_SHA:0:7}"
print_info "Commit SHA: ${SHORT_SHA}"

# Read current version from package.json
if [ ! -f "package.json" ]; then
    print_error "package.json not found!"
    exit 1
fi

CURRENT_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0")
print_info "Current version in package.json: ${CURRENT_VERSION}"

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"
IFS='-' read -r PATCH PRERELEASE <<< "${PATCH}"

# Initialize variables
VERSION=""
TAG_VERSION=""
IS_HOTFIX="false"
BUILD_NUMBER="${GITHUB_RUN_NUMBER:-0}"

# Determine version based on branch
case "${BRANCH_NAME}" in
    main|master)
        # Production release - use version from package.json
        VERSION="${CURRENT_VERSION}"
        TAG_VERSION="v${VERSION}"
        print_info "Production release: ${VERSION}"
        ;;
    
    develop|development)
        # Development build - add pre-release identifier
        VERSION="${MAJOR}.${MINOR}.${PATCH}-dev.${BUILD_NUMBER}+${SHORT_SHA}"
        TAG_VERSION="v${MAJOR}.${MINOR}.${PATCH}-dev.${BUILD_NUMBER}"
        print_info "Development build: ${VERSION}"
        ;;
    
    release/*)
        # Release candidate - extract version from branch name
        RELEASE_VERSION="${BRANCH_NAME#release/}"
        VERSION="${RELEASE_VERSION}-rc.${BUILD_NUMBER}+${SHORT_SHA}"
        TAG_VERSION="v${RELEASE_VERSION}"
        print_info "Release candidate: ${VERSION}"
        
        # Update package.json version for release
        npm version "${RELEASE_VERSION}" --no-git-tag-version --allow-same-version
        print_info "Updated package.json to version: ${RELEASE_VERSION}"
        ;;
    
    hotfix/*)
        # Hotfix - increment patch version
        NEW_PATCH=$((PATCH + 1))
        VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
        TAG_VERSION="v${VERSION}"
        IS_HOTFIX="true"
        print_warning "Hotfix detected: ${VERSION}"
        
        # Update package.json version for hotfix
        npm version "${VERSION}" --no-git-tag-version --allow-same-version
        print_info "Updated package.json to version: ${VERSION}"
        ;;
    
    feature/*|bugfix/*|fix/*)
        # Feature/bugfix branch - add pre-release identifier
        BRANCH_SLUG=$(echo "${BRANCH_NAME}" | sed 's/[^a-zA-Z0-9]/-/g' | cut -c1-20)
        VERSION="${MAJOR}.${MINOR}.${PATCH}-${BRANCH_SLUG}.${BUILD_NUMBER}+${SHORT_SHA}"
        TAG_VERSION="v${MAJOR}.${MINOR}.${PATCH}-${BRANCH_SLUG}.${BUILD_NUMBER}"
        print_info "Feature/bugfix build: ${VERSION}"
        ;;
    
    *)
        # Unknown branch - use current version with branch identifier
        BRANCH_SLUG=$(echo "${BRANCH_NAME}" | sed 's/[^a-zA-Z0-9]/-/g' | cut -c1-20)
        VERSION="${MAJOR}.${MINOR}.${PATCH}-${BRANCH_SLUG}.${BUILD_NUMBER}+${SHORT_SHA}"
        TAG_VERSION="v${MAJOR}.${MINOR}.${PATCH}-${BRANCH_SLUG}.${BUILD_NUMBER}"
        print_warning "Unknown branch type: ${BRANCH_NAME}"
        print_info "Generated version: ${VERSION}"
        ;;
esac

# Export variables to build.env for GitHub Actions
cat > build.env <<EOF
VERSION=${VERSION}
TAG_VERSION=${TAG_VERSION}
IS_HOTFIX=${IS_HOTFIX}
BRANCH_NAME=${BRANCH_NAME}
COMMIT_SHA=${SHORT_SHA}
BUILD_NUMBER=${BUILD_NUMBER}
EOF

print_info "Version information saved to build.env"

# Display summary
echo ""
echo "=========================================="
echo "  Version Generation Complete"
echo "=========================================="
echo "VERSION:      ${VERSION}"
echo "TAG_VERSION:  ${TAG_VERSION}"
echo "IS_HOTFIX:    ${IS_HOTFIX}"
echo "BRANCH:       ${BRANCH_NAME}"
echo "COMMIT:       ${SHORT_SHA}"
echo "BUILD:        ${BUILD_NUMBER}"
echo "=========================================="

exit 0
