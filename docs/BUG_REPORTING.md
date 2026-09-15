# Reporting a bug in AeroTube

Good bug reports get fixed faster. This guide explains what the app collects for you, what you should write, and what never leaves your device.

## Where does the report go?

**Nowhere automatically.** AeroTube has no crash-report backend. The in-app form only *builds* a report:

| Action | Destination |
| --- | --- |
| **Copy** | Your clipboard |
| **Save** | A local `bug-report-*.md` file you choose |
| **File on GitHub** | Opens `github.com/Amadoson3001/aerotube-downloader/issues/new` with title + body prefilled — **you still press Submit new issue** |

If you close the browser without submitting, nothing reaches the maintainer. The report is also copied to the clipboard first as a backup.

## Fastest path (recommended)

1. Reproduce the problem once while **logging is on** (Settings → Logs).
2. Open **Settings → Report a Bug**.
3. Describe:
   - **What went wrong** (one sentence)
   - **Steps to reproduce** (numbered)
   - **What you expected** vs **what happened**
4. Tap:
   - **Copy** — paste into Discord/chat/an existing issue
   - **Save** — write a `bug-report-*.md` file you can attach
   - **File on GitHub** — opens the issue form prefilled; press **Submit new issue** in the browser

You can also tap **Report** inside any error dialog. That pre-fills the error details for you.

## What the report contains

| Section | Source | Why it helps |
| --- | --- | --- |
| Summary / steps / expected | You | Reproduction path |
| Environment table | App version, platform, locale, session id, tool versions | Matches known issues to a build |
| Error details | Last error dialog text | Exact failure the UI saw |
| Recent errors | LoggingService buffer | Context around the failure |
| Log tail | Last ~60 sanitized log lines | Timeline without dumping megabytes |

Every log line in a report is forced through **URL sanitization**: cookies, tokens, and auth query params are redacted even if sanitization was toggled off for live logging.

## What is never included

- Cookie files or cookie values
- Access / refresh tokens, API keys
- Full home-directory usernames in download paths (`C:\Users\•••\...`)
- Private video titles you did not paste yourself

Still, **do not paste private playlist URLs or account emails** into the free-text fields.

## If you are filing on GitHub manually

Use the **Bug report** issue form. Attach:

1. The markdown from **Report a Bug → Copy** (or the saved `.md` file)
2. Optionally a screenshot
3. The public video URL **only if** it is safe to share

Please search open issues first and include the app version in the title when you can.

## Turning logging on

Settings → Logs:

- **Enable logging** — writes `app.log` under the app support directory
- **Sanitize URLs** — recommended always-on for anything you might export
- **Export Logs** — saves the full file for deep debugging
- **View Logs** — live tail inside the app

Logs rotate at ~5 MB (3 rotated files) and are cleaned up after 7 days.

## Session IDs

Each app launch gets a short session id (shown in Report a Bug and in the environment dump). Quote it when a developer asks which run failed — two logs from different sessions are easy to tell apart.

## For maintainers

- Issue form: `.github/ISSUE_TEMPLATE/bug_report.yml`
- In-app builder: `lib/services/core/bug_report_service.dart`
- Dialog: `lib/ui/widgets/bug_report_dialog.dart`
- Logging: `lib/services/core/logging_service.dart`
