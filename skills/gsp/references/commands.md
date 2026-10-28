# gsp command reference

Every command shown by `gsp --help` is listed here. The installed executable's
`--help` is still the authority for its options; check it before use, because a
server may reject an operation the client offers.

Common options apply to authenticated commands: `--profile`, `--json`,
`--verbose`, `--non-interactive`, `--timeout-seconds`, and `--session-store`.
`--verbose` also writes one `gsp timing:` line to standard error for each
stage of a command: the session lock, Keychain or session file reads and
writes, session refreshes, and each HTTP or XRPC request with its NSID, host,
and status. Each line gives the offset from the start of the process and the
duration in milliseconds. The lines never include tokens, bodies, or query
strings, and standard output is unchanged.
Lists take `--skip` and `--max-count` (default 50) and may take `--no-pager`.
Writes that take `--idempotency-key` and `--dry-run` follow the rules in
[workflows.md](workflows.md). Issue and PR commands select the repository with
`-R, --repo OWNER/NAME`; repository commands take a positional repository.

Roles in the "Who" column are the minimum Gitosphere role on the target
(`reader` < `writer` < `admin`, and `owner` has every `admin` permission).
"service admin" means the deployment's service administrator; Organization and
repository owners cannot use those commands. The server decides; treat the
column as guidance, not as a permission check.

## Authentication

| Command | Purpose | Who |
| --- | --- | --- |
| `auth login [ACCOUNT]` | Authorize and store a DPoP-bound session. Interactive OAuth; `--no-browser` and `--callback-port` support SSH, `--pds` overrides the PDS origin, and `--permission-set` selects the OAuth permission set (default `dev.gitosphere.authRepository`). | Any user |
| `auth status` | Show non-secret session status: account, server, realm, store, expiry, `refreshable`. Does not refresh. | Any user |
| `auth logout` | Delete the selected profile's session. | Any user |
| `auth use PROFILE` | Select the default profile without changing its credentials. | Any user |
| `auth id-token --audience AUD --repo OWNER/NAME` | Issue a short-lived OIDC ID token for the signed-in account acting for one repository, for a relying party such as Claude API Workload Identity Federation. `--repo` is required and needs read access. `--lifetime SECONDS` (60-3600, default 300) sets how long it stays valid; `--output FILE` writes the token with mode 0600 instead of standard output. A token can be exchanged once, so issue one per exchange. A server without an ID token key fails with `IdTokenIssuerNotConfigured` (exit 3). | reader |

## Organizations and members

| Command | Purpose | Who |
| --- | --- | --- |
| `org create --name NAME` | Create an Organization. Requires `--idempotency-key`; supports `--dry-run`. | Any signed-in user; becomes owner |
| `org get --organization NAME` or `--organization-id ID` | Show an Organization. | Member |
| `org list` | List Organizations visible to you. | Any user |
| `member list` | List members of an Organization (`--organization`, `--organization-id`) or repository (`--repo`, `--repository-id`). | Member |
| `member add --principal DID --role ROLE` | Add a member with role `owner`, `admin`, `writer`, or `reader`. | admin |
| `member update --principal DID --role ROLE` | Change a member's role. | admin |
| `member remove --principal DID` | Remove a member. | admin |

Membership writes require `--idempotency-key` and support `--dry-run`.
Gitosphere membership is separate from Space membership.

## Repositories

| Command | Purpose | Who |
| --- | --- | --- |
| `repo create NAME` | Create a repository and publish its record. `--public` stores metadata on your PDS; `--internal` or `--private` store it in a Space. Requires `--idempotency-key`. | Any user |
| `repo view [REPOSITORY]` | Show a repository; defaults to the current clone. | reader, or anyone for public |
| `repo list` | List repositories visible to you. | Any user |
| `repo search [QUERY]` | Search public repositories; works without login. | Anyone |
| `repo deactivate [REPOSITORY]` | Deactivate a repository. Requires `--idempotency-key`. | admin |
| `repo clone REPOSITORY [DIRECTORY]` | Clone with ephemeral Git grants and set up the credential helper. | reader |
| `repo remote set REPOSITORY` | Configure a repository-local remote and credential helper (`--remote`, `--force`). | reader |
| `repo tree [REPOSITORY]` | List files at `--ref` and `--path`. | reader |
| `repo blob PATH [REPOSITORY]` | Show a file at `--ref`. | reader |
| `repo diff BASE HEAD` | Show the unified diff between two exact commits (`--repository`, `--color`, `--no-pager`). | reader |
| `repo repair-space-policy` | Point a private repository's Space at the current Gitosphere managing app. Use `--dry-run` first. | admin |

## Spaces

| Command | Purpose | Who |
| --- | --- | --- |
| `space member put --space URI --did DID --read BOOL --write BOOL --yes` | Set both read and write permissions for a Space member. | Space owner |
| `space member add --space URI --did DID --yes` | Older form replaced by `space member put`; prefer `put`. | Space owner |
| `space member list --space URI` | List Space members. | Space owner |
| `space delete --space URI --verification-space URI --yes` | Delete a disposable verification Space. The two URIs must match. | Space owner |

Space commands support `--dry-run`, which validates without contacting the PDS.
Changing Space membership does not change Gitosphere roles.

## Service administration

| Command | Purpose | Who |
| --- | --- | --- |
| `traffic status` | Show admission limits and paused targets. | service admin |
| `traffic pause --target TARGET` | Pause new requests for `auth`, `invite`, `api-write`, `body-write`, `git-read`, `git-write`, or `git-push` (repeatable). | service admin |
| `traffic resume --target TARGET` | Resume paused targets. | service admin |
| `quota usage --scope SCOPE --subject SUBJECT` | Show usage for a `did`, `organization`, or `repository`. | Yourself, an active member, or a reader of the repository; service admin for any |
| `quota show --scope SCOPE --subject SUBJECT` | Show the effective limits; `default` scope is also accepted. | Same as `quota usage` |
| `quota list` | List configured quotas. | service admin |
| `quota set --scope SCOPE --subject SUBJECT` | Set `--repository-limit`, `--byte-limit`, or `--push-limit`. | service admin |
| `quota reset --scope SCOPE --subject SUBJECT` | Remove an override and return to the default. | service admin |
| `quota reconcile --scope SCOPE --subject SUBJECT` | Recalculate recorded usage. | service admin |
| `invite create` | Issue an invitation code (`--max-uses`, `--expires-in-seconds`). The code is shown only in the first successful response. | service admin |
| `invite list` | List invitation metadata without codes. | service admin |
| `invite revoke INVITE_ID` | Revoke an invitation. | service admin |
| `invite redeem` | Redeem a code for your DID. Read it with `--code-file PATH` or `--code-file -`; otherwise it is prompted without echo. | Any user |
| `access status` | Show your own service admission status. | Any user |
| `access list` | List service admissions. | service admin |
| `access grant DID` | Grant service access. | service admin |
| `access suspend DID` | Suspend service access. | service admin |
| `access resume DID` | Resume suspended access. | service admin |

Administrative writes require `--idempotency-key` and support `--dry-run`.
Treat invitation codes as secrets.

## Access decisions and audit

| Command | Purpose | Who |
| --- | --- | --- |
| `access explain --kind KIND --principal DID --action ACTION` | Ask the server to evaluate a policy decision for an `organization`, `project`, `repository`, `space`, or `record` target. An evaluated denial exits `5` with the decision on stdout. | Member of the target |
| `audit list` | List secret-safe audit events visible to you. | Any user |

## Issues

| Command | Purpose | Who |
| --- | --- | --- |
| `issue create --title TITLE` | Create an Issue (`--body`, `--body-file`, `--editor`, `--parent`). | writer |
| `issue list` | List Issues. `--state open|closed|all` and relation filters `--parent`, `--related`, `--blocking`, `--blocked-by`, `--has-children`, `--blocked`. | reader |
| `issue view ISSUE` | Show an Issue with its relations and, except with `--json`, its comments. | reader |
| `issue edit ISSUE` | Edit the title or body, or change exactly one relation (`--parent`, `--remove-parent`, `--add-sub-issue`, `--remove-sub-issue`, `--add-related`, `--remove-related`, `--add-blocking`, `--remove-blocking`, `--add-blocked-by`, `--remove-blocked-by`). Repeating a relation option is rejected. | writer |
| `issue close ISSUE` | Close an Issue. | writer |
| `issue reopen ISSUE` | Reopen an Issue. | writer |
| `issue comment ISSUE` | Add a comment (`--body`, `--body-file`; opens an editor when neither is given). `--dry-run` signs the comment without writing it. | writer |
| `issue comments ISSUE` | List an Issue's comments, oldest first. Edited comments carry `updatedAt`. | reader |
| `issue edit-comment ISSUE --comment URI` | Replace the body of a comment you wrote (`--body`, `--body-file`). The comment keeps its record key and creation time. | The comment's author, with writer |
| `issue adopt-baseline` | Review existing Issue records with `--dry-run`, then adopt them with the returned `--source-digest`. An administrative migration, not routine repair. | admin |
| `issue resume-mutation OPERATION_ID` | Resume publishing and committing a prepared Issue mutation after an interruption. | The original writer |

`ISSUE` accepts `NUMBER`, `#NUMBER`, `OWNER/REPO#NUMBER`, or an Issue AT URI.
Passing `--body` or `--body-file` to `issue edit` stores the body as Markdown
even when the text is unchanged; an unchanged `--editor` session sends nothing.

## Pull requests

| Command | Purpose | Who |
| --- | --- | --- |
| `pr create --title TITLE` | Create a PR from `--head` into `--base` (`--body`, `--body-file`). | writer |
| `pr list` | List PRs (`--state open|closed|merged|all`, `--author DID`). | reader |
| `pr view NUMBER` | Show a PR with its rounds; the human output ends with the current round's reviews. JSON stays the PR alone. | reader |
| `pr edit NUMBER` | Edit the title or body (`--title`, `--body`, `--body-file`, `--editor`). | writer |
| `pr diff NUMBER` | Show the unified diff for a round (`--round`, `--color`, `--no-pager`). | reader |
| `pr comment NUMBER` | Add a comment or finding (`--body`, `--body-file`, `--round`, `--at [base:|head:]PATH[:LINE[-END]]`, `--severity info|low|medium|high|critical`, `--category`, `--blocking`). `--at` lines must be inside one hunk of the round's diff on that side; `--at PATH` comments on a changed file. A location outside the diff fails with `InvalidDiffLocation` (exit 3), whose message lists the lines the diff shows. `--path`, `--side`, `--start-line`, and `--line` remain for compatibility. `--reply-to COMMENT_URI` replies to a top-level comment of the same PR; a reply takes that comment's round and location, so it rejects `--round`, `--at`, the location options, `--severity`, `--category`, and `--blocking`, and the server rejects other targets with `InvalidReplyTo`. Opens an editor when no body option is given. | writer |
| `pr comments NUMBER` | List comments (`--round`) as threads: current-round threads first, then `Earlier rounds`; line comments show an excerpt of the commented lines from the recorded commit, and earlier-round comments show `outdated` or `unchanged`. JSON stays a flat `comments[]` with `replyTo`, `context` (excerpt lines), and `locationChanged`. Each comment's `uri` identifies it for editing and replies. Authors show as `handle (DID)` from the handle verified when the comment was signed; the DID is authoritative. | reader |
| `pr edit-comment NUMBER --comment URI` | Replace the body of a comment you wrote (`--body`, `--body-file`). Its round, position, severity, blocking flag, and creation time are kept. | The comment's author, with writer |
| `pr review NUMBER` | Record one of `--comment`, `--approve`, or `--request-changes` (`--body`, `--body-file`, `--evidence-file`, `--unverified`). | writer; approval excludes the PR author |
| `pr reviews NUMBER` | List reviews (`--round`) with their decision, reviewer as `handle (DID)`, round, and plain-text body: current round first, then `Earlier rounds`. `counts` marks the reviews the current decision is made from (`qualifying`); JSON is `reviews[]`. | reader |
| `pr status NUMBER` | Show approvals with the approvers as `handle (DID)`, blocking findings, and whether the PR is mergeable. JSON adds `approvers` (`did`, `handle`, `reviewUri`) next to `status`. | reader |
| `pr merge NUMBER --match-head-commit SHA` | Merge the reviewed head. Use `--dry-run` first. | writer; protected default branch needs admin |

## Events

Events carry identifiers only (`type`, `pullRequest`, `round`, `roundReason`,
`issue`, `state`, `actor`); read the PR or Issue again for its content. Each event
has a `cursor` string. Save the cursor of the last event you processed and pass it
to `--after` to continue. Exit status 6 (`CursorExpired`) means the events after the
cursor are no longer kept (30 days): drop the cursor and read the current state again.
A cursor from another repository exits 64 (`CursorMismatch`). `--kind` filters
without holding the cursor back. Event types are listed in the server's
`docs/repository-events.md`.

| Command | Purpose | Who |
| --- | --- | --- |
| `events list` | Print events after `--after`, from the oldest kept event without it (`--kind`, `--max-count` up to 1000, `--no-pager`). JSON has `events` and `nextCursor`. `gsp events` alone runs this. | reader |
| `events watch` | Keep polling (`--interval`, default 10 seconds) and print each new event as one JSON line. Without `--after` it starts from now. Temporary failures are retried; other failures exit with their status. | reader |

An event consumer that restarts the command can resume like this:

```sh
gsp events watch --repo OWNER/NAME ${CURSOR:+--after "$CURSOR"}
```

## Shell completion

| Command | Purpose | Who |
| --- | --- | --- |
| `completion SHELL` | Write a completion script for `bash`, `zsh`, or `fish` to stdout. | Anyone |
