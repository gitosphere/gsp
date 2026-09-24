# gsp

The official Gitosphere CLI and agent skill.

`gsp` connects people and coding agents to Gitosphere, a permissioned Git
collaboration platform built on AT Protocol. Use it for authentication,
repositories, issues, pull requests, organizations, access decisions, and audit
information. Use ordinary Git for local history, commits, fetches, and pushes.

## Supported platforms

`gsp` supports macOS on Apple Silicon (arm64). See
[Releases](https://github.com/gitosphere/gsp/releases) for supported macOS versions.

## Install

```sh
brew install --cask gitosphere/tap/gsp
command -v gsp
gsp --version
gsp --help
```

Official releases are signed with Developer ID and notarized by Apple.

See [installation and operation](docs/installation.md) for manual installation,
upgrades, rollback, removal, shell completion, profiles, and Agent Skill setup.

## Get started

Have an invitation code? Follow [Get started with an invitation](docs/getting-started.md)
to redeem it, create a private personal repository, and push your first commit.

For users who already have service access, these commands discover and clone a repository:

```sh
gsp auth status --json
gsp repo search --json YOUR_QUERY
gsp repo clone OWNER/REPOSITORY
```

For authenticated automation, check the selected profile, server origin, realm,
and session status first. Use `--json` and `--non-interactive` where supported;
consult the installed command's help for its contract.

## Agent Skill

The matching release includes the complete `skills/gsp` directory, with
`SKILL.md`, `agents/`, and `references/`. A Cask installation makes it available
under `$(brew --prefix)/share/gsp/skills/gsp`. Copy the whole directory into the
Skill location supported by your agent, then reload its skills. The CLI and Cask
do not register skills in an agent's configuration automatically.

## Support

For bug reports, feature requests, or help using `gsp`, open an issue in
[this repository](https://github.com/gitosphere/gsp/issues).

See the [project overview](https://github.com/gitosphere/gitosphere) to learn
more about Gitosphere.
