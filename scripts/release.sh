#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="$PROJECT_ROOT/src/project.yml"

bump_version() {
    local type="${1:-minor}"
    
    # Get current version
    local current=$(grep 'INFOPLIST_KEY_CFBundleShortVersionString:' "$PROJECT_YML" | sed 's/.*"\([^"]*\)".*/\1/')
    
    # Parse version
    IFS='.' read -r major minor patch <<< "$current"
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}
    
    # Bump version
    case "$type" in
        major) ((major++)); minor=0; patch=0 ;;
        minor) ((minor++)); patch=0 ;;
        patch) ((patch++)) ;;
    esac
    
    local new_version="$major.$minor.$patch"
    
    # Update project.yml
    sed -i '' "s/INFOPLIST_KEY_CFBundleShortVersionString: \"[^\"]*\"/INFOPLIST_KEY_CFBundleShortVersionString: \"$new_version\"/" "$PROJECT_YML"
    sed -i '' "s/INFOPLIST_KEY_CFBundleVersion: \"[^\"]*\"/INFOPLIST_KEY_CFBundleVersion: \"$new_version\"/" "$PROJECT_YML"
    
    echo "Version bumped: $current -> $new_version"
    
    # GitHub Actions output
    if [[ -n "$GITHUB_OUTPUT" ]]; then
        echo "version=$new_version" >> "$GITHUB_OUTPUT"
        echo "version_type=$type" >> "$GITHUB_OUTPUT"
    fi
    if [[ -n "$GITHUB_ENV" ]]; then
        echo "VERSION=$new_version" >> "$GITHUB_ENV"
    fi
    
    echo "$new_version"
}

build() {
    local version="$1"
    
    # Generate Xcode project
    cd "$PROJECT_ROOT/src"
    xcodegen generate > /dev/null
    
    # Build with explicit destination
    xcodebuild -project Spotless.xcodeproj -scheme Spotless -configuration Release \
        -destination 'platform=macOS' \
        build \
        CODE_SIGN_IDENTITY='-' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
        > /dev/null 2>&1
    
    # Get app path - use SYMROOT to find build directory
    local built_products_dir=$(xcodebuild -project Spotless.xcodeproj -scheme Spotless -configuration Release \
        -destination 'platform=macOS' \
        -showBuildSettings -quiet 2>&1 | grep 'BUILT_PRODUCTS_DIR =' | head -1 | sed 's/.*= //')
    
    local app_path="$built_products_dir/Spotless.app"
    
    if [[ ! -d "$app_path" ]]; then
        echo "Error: App not found at $app_path"
        exit 1
    fi
    
    # Ad-hoc sign the app (allows running without developer certificate)
    codesign --force --deep --sign - "$app_path" > /dev/null 2>&1
    
    # Create DMG with Applications folder symlink
    local dmg_name="Spotless-$version.dmg"
    local dmg_path="$PROJECT_ROOT/$dmg_name"
    local dmg_temp="$PROJECT_ROOT/dmg_temp"
    
    mkdir -p "$dmg_temp"
    cp -R "$app_path" "$dmg_temp/"
    ln -s /Applications "$dmg_temp/Applications"
    
    hdiutil create -volname "Spotless" -srcfolder "$dmg_temp" -ov -format UDZO "$dmg_path" > /dev/null 2>&1
    
    rm -rf "$dmg_temp"
    
    # Sign the DMG as well
    codesign --force --sign - "$dmg_path" > /dev/null 2>&1
    
    echo "$dmg_name"
}

changelog() {
    local version="$1"
    local version_type="${2:-minor}"
    local changelog_file="$PROJECT_ROOT/CHANGELOG.md"
    local prev_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    # Determine commit types to include based on version type
    # major/minor: include feat and fix
    # patch: only include fix
    local commit_filter
    case "$version_type" in
        major|minor) commit_filter="^feat|^fix" ;;
        patch) commit_filter="^fix" ;;
        *) commit_filter="^feat|^fix" ;;
    esac
    
    # Generate log for this version, filtered by commit type
    local log
    if [[ -n "$prev_tag" ]]; then
        log=$(git log "$prev_tag"..HEAD --pretty=format:"%s" --no-merges | grep -E "$commit_filter" | sed 's/^/- /')
    else
        log=$(git log --pretty=format:"%s" --no-merges | grep -E "$commit_filter" | sed 's/^/- /')
    fi
    
    # Create new version entry
    local entry="## v$version\n\n$log\n"
    
    # Prepend to CHANGELOG.md
    if [[ -f "$changelog_file" ]]; then
        echo -e "$entry$(cat "$changelog_file")" > "$changelog_file"
    else
        echo -e "$entry" > "$changelog_file"
    fi
    
    # GitHub Actions multiline output
    if [[ -n "$GITHUB_OUTPUT" ]]; then
        {
            echo 'body<<EOF'
            echo -e "$log"
            echo 'EOF'
        } >> "$GITHUB_OUTPUT"
    fi
}

# Main
case "$1" in
    bump_version)
        bump_version "$2"
        ;;
    build)
        build "$2"
        ;;
    changelog)
        changelog "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {bump_version|build|changelog} [args]"
        exit 1
        ;;
esac
