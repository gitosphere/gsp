# Gitosphere workflows

Use only the sections relevant to the request. Examples use placeholders such
as `PROFILE`, `OWNER/REPO`, and `NUMBER`; resolve them before execution. Verify
every command and option against the installed executable's help.

## Authentication and environment

For authenticated operations, inspect:

```sh
gsp --profile PROFILE auth status --json
```

Check `result.serverOrigin`, `securityRealmID`, `account`, `sessionStore`,
`expiresAt`, `refreshable`, and `sessionStoreCleanupPending`. Keep the selected
profile and deployment explicit throughout the task. A normal authenticated
request can refresh an expired but refreshable session. If it fails, interpret
the actual error before deciding whether interactive login is needed.

When login is required, the user completes OAuth for the intended account.
`auth login ACCOUNT` is interactive; `--non-interactive` is not a substitute for
user consent. For SSH, `--no-browser` and `--callback-port PORT` support a browser
on the user's machine with a matching SSH port forward. Treat the authorization
URL as sensitive and do not copy it into Issues, PRs, or validation artifacts.

Storage selection is explicit. `--session-store file` selects protected local
JSON storage, not encrypted storage; respect an existing profile's selection.
Do not switch stores or profiles merely to bypass a failure. Switching stores
uses a new OAuth login and can require access to the old store. With
`sessionStoreCleanupPending: true`, use the documented same-profile login
recovery; do not delete session files or lock files manually. File-store
diagnostics may inspect ownership, permissions, and symlinks without reading
secret contents. Each host authenticates independently.

## Discovery, clone, and remote setup

```sh
gsp repo search QUERY --json --non-interactive
gsp --profile PROFILE repo view OWNER/REPO --json --non-interactive
gsp --profile PROFILE repo clone OWNER/REPO DESTINATION --dry-run --json --non-interactive
gsp --profile PROFILE repo remote set OWNER/REPO --dry-run --json --non-interactive
```

Search is public and can run without login. This does not imply that viewing
private content, cloning, or modifying a repository is anonymous. Resolve the
repository identity, deployment, and destination before clone/remote setup.
Remove `--dry-run` only for an authorized setup operation. Remote setup changes
local Git configuration; do not add `--force` without resolving the conflict.

The CLI configures the installed credential helper. Let Git invoke it through
the credential protocol; never call it to display credentials. Git must support
the required `authtype` and `state` capabilities. Report a capability failure
instead of embedding tokens in a URL or replacing the authentication mechanism.
After setup, use ordinary Git for branch, commit, fetch, and push operations
within the user's request. A successful clone or fetch does not grant push access.

## Organizations, members, access, and audit

```sh
gsp --profile PROFILE org get --organization ORG --json --non-interactive
gsp --profile PROFILE member list --repo OWNER/REPO --json --non-interactive
gsp --profile PROFILE member add --repo OWNER/REPO --principal DID --role reader \
  --idempotency-key REQUEST_KEY --dry-run --json --non-interactive
gsp --profile PROFILE access explain --kind repository --repository-id REPOSITORY_ID \
  --principal DID --action read --json --non-interactive
gsp --profile PROFILE audit list --limit 50 --json --non-interactive
```

Organization commands resolve public names or explicit immutable IDs. Member
commands target an organization or repository; confirm the target, principal,
current membership, and requested role before adding, updating, or removing.
Use the separate `space member` commands only for requested Space membership
changes. Do not escalate a Gitosphere role or alter Space membership as an
automatic response to an access denial.

`access explain` asks the server to evaluate policy. An evaluated denial returns
a result on stdout with exit status `5`; it is not necessarily an error envelope.
Use the returned decision and reasons, not a locally reconstructed role hierarchy.
Audit reads are scoped to the authenticated caller and realm. Keep reports
limited to the requested evidence; do not export raw audit data unnecessarily.

## Pagination and structured output

Successful structured responses use `schemaVersion` and `result`, with an
optional request ID. List results expose `result.page.nextCursor`. Feed that
value unchanged into the same command's `--cursor`, retaining the profile,
repository, and filters. Stop when there is no next cursor or the requested
bound is reached. Do not decode cursors or treat `--limit` as a total-result cap.

`issue list` can retrieve multiple pages internally. Its `--skip` and
`--max-count` control the returned selection; `--limit` controls each API page.
Read the actual returned cursor before fetching more. State filters matter:
for example, use `--state all` when the request includes closed Issues and the
installed command supports it. If a cursor becomes stale, start a fresh listing
with the same filters and deduplicate by stable identity; do not splice cursors
from different queries or claim a complete snapshot across concurrent changes.

## Issues and Markdown writes

Inspect the target with `issue view NUMBER --repo OWNER/REPO --json` first for
an edit or state transition. Use `--repo` to avoid ambiguous clone context.

```sh
gsp --profile PROFILE issue create --repo OWNER/REPO --title TITLE \
  --body-file issue.md --idempotency-key REQUEST_KEY --dry-run --json --non-interactive
gsp --profile PROFILE issue edit NUMBER --repo OWNER/REPO --body-file issue.md \
  --idempotency-key REQUEST_KEY --dry-run --json --non-interactive
```

For the authorized write, remove `--dry-run`, keeping the reviewed input. Read
the Issue back and compare the actual body, including newlines and literal
backslash sequences. Do not pass JSON-escaped Markdown as a shell argument.
Close/reopen use the same inspect, target, idempotency, and read-back discipline.
Creation may generate a key when omitted, but automation that may retry should
supply one. Non-interactive edits require a key. Reuse a key only for identical
logical requests; an idempotency conflict is not permission to try a fresh key.

On revision conflicts, fetch the current state and reconcile concurrent changes
with the user's intent before a new write. On interrupted mutations, inspect
the returned operation ID and supported `issue resume-mutation` workflow; retain
the same profile and repository. Baseline adoption is an administrative migration,
not routine repair for a failed edit. Do not adopt or reset data automatically.

## Pull requests, reviews, and merges

Use native Gitosphere commands for PRs. Inspect existing PRs to avoid duplicates,
and confirm the exact repository, base, head, and commits before creation.

```sh
gsp --profile PROFILE pr list --repo OWNER/REPO --json --non-interactive
gsp --profile PROFILE pr create --repo OWNER/REPO --base BASE --head HEAD \
  --title TITLE --body-file pr.md --idempotency-key REQUEST_KEY \
  --dry-run --json --non-interactive
gsp --profile PROFILE pr view NUMBER --repo OWNER/REPO --json --non-interactive
```

Push the authorized branch to the intended Gitosphere remote before creating
the PR. Do not publish it to a GitHub mirror instead. Use `Closes #N` only when
the change completes the Issue; use `See #N` for partial work. Preserve the body
with a file and confirm it through read-back after creation or editing.

Reviews and comments are writes. If requested, inspect the current PR and round,
then use the installed `pr review` options (`--comment`, `--approve`, or
`--request-changes`) and body-file support. Supply a stable key where supported.
Do not add a guessed `--dry-run` to review commands. Keep verification evidence
separate from unverified scope and never infer approval from a request to read.

A request to create a PR does not authorize merging it. For an authorized merge,
inspect `pr status` and `pr view`, pin the full reviewed head SHA, and verify the
merge with the supported dry-run before applying it:

```sh
gsp --profile PROFILE pr merge NUMBER --repo OWNER/REPO \
  --match-head-commit REVIEWED_FULL_SHA --idempotency-key REQUEST_KEY \
  --dry-run --json --non-interactive
```

The current merge/Issue-close contract requires `issueCloseVersion: 1` in the
dry-run response. On `MergeCloseContractUnavailable`, report incompatibility;
do not bypass the gate. A merge can succeed while auto-closing Issues fails:
stdout retains the merge result and `issueCloseResults`, stderr can report
`IssueAutoCloseIncomplete`, and the process exits `3`. Inspect those results
before retrying. Resume supported incomplete work with the same profile,
repository, PR, reviewed SHA, and key; do not create another merge or reinterpret
the entire operation as failed. Verify final PR and Issue states separately.

## Failure handling

Use process status as the first discriminator, then parse any JSON error on
stderr. The error envelope has top-level `schemaVersion`, `exitCode`, and `error`;
fields such as `category`, `code`, `retryable`, `retryAfterSeconds`, and `requestId`
are under `error`. Human-readable messages are diagnostics, not stable selectors.
Inspect stdout too, because a nonzero exit can accompany a decision or partial
result. If an older CLI emits text instead, preserve its process status and safe
diagnostic rather than inventing JSON fields.

| Exit | Meaning | Action |
| --- | --- | --- |
| 0 | Success | Inspect the result and verify writes when applicable. |
| 1 | Unexpected failure | Inspect safe diagnostics and establish any write outcome. |
| 2 | Cancelled | Stop; do not automatically restart the operation. |
| 3 | API failure | Inspect the error code, compatibility, conflicts, and partial results. |
| 4 | Authentication/session failure | Diagnose the selected profile/store; use same-profile login only when needed. |
| 5 | Access denied | Inspect a returned decision or error; do not escalate privileges automatically. |
| 64 | Invalid usage/configuration | Recheck installed help and explicit target configuration. |
| 75 | Temporary failure | Respect retry metadata; retry safe reads within a bounded budget, reconcile writes first. |

`retryable: true` does not prove that repeating a write is safe. A timeout or lost
response can occur after a mutation was accepted. Preserve operation IDs and
idempotency keys privately for recovery, verify current state, and report an
unresolved outcome when the available interface cannot establish it.
