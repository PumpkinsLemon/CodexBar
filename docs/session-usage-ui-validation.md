---
summary: Installed-app session inspector verification and remaining menu proof.
read_when:
  - Reviewing session usage inspection and its UI evidence.
---

# Session inspector UI verification

Verified the installed arm64 `0.79.0-session-trial3` application on macOS 15.7.9.
Build source `93e9aec` contains feature source `590a2b1`; the release build used
Xcode 26.6 and Swift 6.3.3. See the
[successful build](https://github.com/PumpkinsLemon/CodexBar/actions/runs/39583612615).

The checks below used the actual Settings window and local session records,
with native app controls. These screenshots are distinct from the earlier
synthetic component renders. The user reviewed and approved the screenshots
with opaque masks covering session names, IDs, search text, account/source
configuration, timestamps, and usage/cost values. No replacement values were
inserted.

| Installed-app check | Result |
| --- | --- |
| Search by saved session title | Matching session retained; unrelated visible row removed. |
| Search by partial session ID | The same matching session retained. |
| Sort by cost, descending and ascending | Direction and visible row ordering updated. |
| Sort by tokens, ascending and descending | Direction and visible row ordering updated. |
| Select another session | Selection and accounting detail changed together. |
| Enable Hide personal info, then return to Sessions | Titles and full IDs hidden in session inspection. |
| Restore original preferences | Hide personal info restored to off; temporary menu shortcut cleared. |

Privacy was changed through the Advanced tab and then checked on returning to
Sessions in the same Settings window. This does not establish behavior while
the inspector remains visibly mounted. The sorting checks inspect visible
rows; the focused model tests cover ordering independently.

## Redacted installed-app screenshots

### Title search

![Saved title search in the installed application](screenshots/session-usage-title-search-redacted.png)

### Cost sorting

![Cost sorting in the installed application](screenshots/session-usage-cost-descending-redacted.png)

### Privacy setting applied to inspection

![Privacy masking in the installed application](screenshots/session-usage-privacy-redacted.png)

## Remaining proof

Cost-menu session-row and search-icon activation have **not** been verified
through the installed menu. Computer Use permission was granted, but the tool
could not reach the status item; its temporary shortcut did not open the menu.
The shortcut was removed after the attempt.

Native event-handler tests use controlled event-tracker input. They do not prove
OS event delivery, full-row clicks, drag-out cancellation, or menu dismissal in
the installed application. Keep these paths pending and retain the draft until
the remaining behavior proof and maintainer feature approval are resolved.
