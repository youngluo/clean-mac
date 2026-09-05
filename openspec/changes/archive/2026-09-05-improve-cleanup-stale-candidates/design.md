## Context

Routine cache candidates are scanned before the user confirms the cleanup plan. A directory such as `~/Library/Developer/Xcode/DerivedData` can be modified by Xcode between scanning and applying. The current `validate` method intentionally compares the measured size again, but reports that mismatch as `invalidPath`, which makes a valid allowlisted path look unsafe.

## Decisions

### 1. Keep the safety boundary strict

The executor continues to reject paths that are not absolute, are outside the configured roots, are excluded, are protected, are symbolic links, no longer exist, or have changed size. No candidate is removed after an ambiguous validation result.

### 2. Capture and verify file identity

Filesystem candidates capture a stable file-resource identifier during scanning when available. The executor compares it immediately before removal. A path replacement is reported as a changed candidate even when the replacement happens to have the same aggregate size.

### 3. Classify stale candidates separately

Size or identity changes use a dedicated `candidateChanged` error and localized message. The existing invalid-path message remains reserved for path-policy failures. Existing history entries remain decodable because the new localized message is additive.

### 4. Require explicit re-confirmation

The changed candidate remains untouched. After a partial cleanup caused by a changed candidate, the review actions expose “重新扫描”; the user receives a fresh candidate snapshot instead of silently retrying the old plan or rerunning the completed operations.

## Verification

- Unit tests cover changed directory size and replaced directory identity.
- Unit tests verify that changed candidates remain on disk and produce the new localized reason.
- Existing path-boundary, symlink, permission, and successful Trash tests remain unchanged.
- Debug build and app restart follow the project instructions.
