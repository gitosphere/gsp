# Get started with an invitation

This guide takes you from an invitation code to your first private repository and Git push. It assumes `gsp` is installed on macOS with Apple Silicon. For installation, upgrades, shell completion, and removal, see [Installation and operation](installation.md).

## 1. Sign in

Use the handle of the AT Protocol account you want to use with Gitosphere. Choose a profile name so this account and its server are explicit in later commands:

```sh
gsp --profile personal auth login YOUR_HANDLE
gsp --profile personal auth status --json
```

Check that the status shows the intended account, server origin, and security realm. On macOS, `gsp` stores credentials in Keychain by default. Authenticate separately on each Mac you use.

Signing in authenticates your account; an invitation is still required to use the Gitosphere service.

## 2. Redeem your invitation

The invitation code is supplied by your inviter or a Gitosphere service administrator. Redeem it with a unique idempotency key:

```sh
gsp --profile personal invite redeem \
  --idempotency-key redeem-first-invitation
```

`gsp` prompts for the code without echoing it. Do not put the code in a command argument, shell history, Issue, or log. If the request times out and the result is unclear, retry the same redemption with the same idempotency key.

Confirm that your service access is active:

```sh
gsp --profile personal access status --json
```

If it remains unregistered, or the code is rejected, contact the person who provided the invitation. Do not post the code when asking for help.

## 3. Create a private personal repository

Choose a repository name and create it as private:

```sh
gsp --profile personal repo create my-first-repo \
  --private \
  --idempotency-key create-my-first-repo
```

A name without an `ORG/` prefix creates a repository owned by your account. The command prints the canonical `OWNER/NAME` and Git URL. Use the printed `OWNER/NAME` in the next command; personal repository owners may be shown as your DID.

## 4. Make your first commit

Clone the empty repository, create its initial branch and commit, then push it:

```sh
gsp --profile personal repo clone OWNER/NAME my-first-repo
cd my-first-repo
git switch --orphan main
printf '# My first repository\n' > README.md
git add README.md
git commit -m "Initial commit"
git push -u origin main
```

`gsp repo clone` configures Git access for the repository. Use ordinary Git for commits, fetches, and pushes. Your private repository is initially available only to its owner; organization membership and sharing with other people are separate steps.

## 5. Prepare Issues in a new repository

Before the first Issue mutation, the repository owner must review and adopt the current Issue baseline. This is also required when the repository has no Issues. Check the list first:

```sh
gsp --profile personal issue list \
  --repo OWNER/NAME --state all --json
```

For an empty repository, preview the baseline and adopt the exact digest returned by the preview:

```sh
gsp --profile personal issue adopt-baseline \
  --repo OWNER/NAME --dry-run --json

gsp --profile personal issue adopt-baseline \
  --repo OWNER/NAME --source-digest SOURCE_DIGEST \
  --non-interactive --json
```

If the repository already contains Issues, review their content and state before adopting the snapshot. Do not adopt records you have not reviewed. After adoption, Issue creation and updates are available:

```sh
gsp --profile personal issue create \
  --repo OWNER/NAME \
  --title "Track the next step" \
  --body "Describe the work" \
  --idempotency-key create-first-issue
```

## Troubleshooting

- `InvitationRequired` means you are signed in, but this account has not redeemed a valid invitation for the selected service. Check the profile with `auth status` and service admission with `access status`.
- `DependencyUnavailable` can indicate a temporary service or data-source problem. For a new repository's first Issue mutation, also verify that its Issue baseline was reviewed and adopted as described above.
- When asking for help, include the exact error output. For commands run with `--json`, include the JSON error, and include the output of `gsp --version --verbose` if requested. Never include invitation codes, session data, or tokens.
