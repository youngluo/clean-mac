## 1. Candidate provider identity

- [x] 1.1 Add a typed `CleanupProvider` identity to every cleanup candidate.
- [x] 1.2 Pass the matching provider from all four scan providers and remove string-based group inference.
- [x] 1.3 Update cleanup validation and related logic so source copy is not used as provider identity.

## 2. Unified scan explanation

- [x] 2.1 Place the current scanning provider explanation in a unified provider-panel slot.
- [x] 2.2 Remove per-provider explanation rows and keep a fixed-height, animated explanation slot.
- [x] 2.3 Move the explanation slot below the provider-panel title and keep it compact.
- [x] 2.4 Keep the explanation to one line and marquee only when it overflows.
- [x] 2.5 Prefix each active scan explanation with “正在”.
- [x] 2.6 Relax the scan-progress panel spacing and give provider rows a consistent minimum height.
- [x] 2.7 Remove redundant provider outcome text while retaining count and size.
- [x] 2.8 Emit candidate discoveries and update the active provider count in real time.

## 3. Stable candidate anchors

- [x] 3.1 Group candidates and determine provider-row clickability from the shared typed provider identity.
- [x] 3.2 Attach stable provider IDs to candidate group headers and defer scroll execution until layout is ready.
- [x] 3.3 Verify all four provider rows, especially “应用残留”和“空间分析”, navigate to matching groups.
- [x] 3.4 Make each group a stable unary view and scroll directly by its typed provider ID.
- [x] 3.5 Use eager group layout to avoid delayed bottom-anchor failures.
- [x] 3.6 Gate provider navigation until the review list is mounted and replay pending targets on appear.
- [x] 3.7 Bind each provider ID to its category header and scroll the header to the top instead of centering the full category container.
- [x] 3.8 Increase the candidate review scroll region maximum height to 720 while retaining the 320 minimum.

## 4. Verification

- [x] 4.1 Run OpenSpec validation and `git diff --check`.
- [x] 4.2 Build the Debug app, close the old instance, and launch the new build.
- [x] 4.3 Re-run validation, build, and launch after the explanation layout adjustment.
- [x] 4.4 Re-run validation, build, and launch after the marquee adjustment.
