# Installation and operation

`gsp` is available for macOS on Apple Silicon (arm64). Check the
[Homebrew Cask](https://github.com/gitosphere/homebrew-tap/blob/main/Casks/gsp.rb)
for the supported macOS version and [GitHub Releases](https://github.com/gitosphere/gsp/releases)
for available artifacts.

## Homebrew

```sh
brew install --cask gitosphere/tap/gsp
command -v gsp
gsp --version
brew upgrade --cask gitosphere/tap/gsp
brew reinstall --cask gitosphere/tap/gsp
```

## Shell completion

The Cask installs completion files for zsh, bash, and fish. Enable completion
for your shell, then type `gsp ` and press Tab to see available commands.

### zsh (macOS default)

Make sure Homebrew's `brew shellenv` setup runs before completion is initialized.
If your `~/.zshrc` or shell framework does not already initialize completion,
add these lines to `~/.zshrc`:

```zsh
autoload -Uz compinit
compinit
```

Open a new terminal. If you use Oh My Zsh, it initializes completion for you;
place Homebrew's setup before loading Oh My Zsh.

### bash

If Homebrew completion is already enabled, open a new terminal to load `gsp`'s
completion. Otherwise, add this line to `~/.bash_profile` for macOS Terminal,
or to `~/.bashrc` if that is your interactive shell's startup file:

```bash
source <(gsp completion bash)
```

### fish

Homebrew-installed fish loads the Cask's completion automatically. Open a new
terminal. For fish installed another way, add this to `~/.config/fish/config.fish`:

```fish
set -p fish_complete_path (brew --prefix)/share/fish/vendor_completions.d
```

See [Homebrew's shell completion guide](https://docs.brew.sh/Shell-Completion)
for additional setup and troubleshooting.

## Sign in

Sign in with your AT Protocol handle and check your account:

```sh
gsp auth login YOUR_HANDLE
gsp auth status
```

On macOS, credentials are stored in Keychain by default. Sign in separately on
each Mac you use.

## Agent Skill

For a Cask installation, set the destination supported by your agent:

```sh
gsp_skill_root="/absolute/path/to/your/agent/skills"
mkdir -p "$gsp_skill_root"
if [ ! -e "$gsp_skill_root/gsp" ] && [ ! -L "$gsp_skill_root/gsp" ]; then
  cp -R "$(brew --prefix)/share/gsp/skills/gsp" "$gsp_skill_root/gsp"
fi
```

For manual installation, copy `skills/gsp` from the same versioned distribution
instead. A copy remains on that version until you update it. If your agent
supports symlinks, linking to the Cask's shared Skill directory follows subsequent
Cask upgrades and stops working after uninstall. Choose this behavior explicitly.

Before updating, inspect and move aside an existing Skill directory or symlink;
do not merge old and new files. Replace the entire directory, reload the agent's
skills, and check that `SKILL.md`, `agents/openai.yaml`, and
`references/workflows.md` are present. Verify the installed CLI with `--version --verbose`
and command help. Skill instructions do not establish server compatibility.

## Removal

Sign out before uninstalling the CLI:

```sh
gsp auth logout
brew uninstall --cask gitosphere/tap/gsp
```

The Cask removes its executable, shared Skill/docs, and completion links. It does
not delete copied agent skills, profiles, or sessions. Remove your agent's copy
or symlink and manual shell configuration deliberately. For manual installation,
remove the selected version directory and its PATH entry after logout.
If you use multiple profiles, sign out of each one you intend to remove.

## Manual installation and rollback

Download `gsp-VERSION-macos-arm64.dmg` from that version's GitHub Release.
Compare its SHA-256 with the `sha256` value in the matching version of
[`gitosphere/homebrew-tap`'s Cask](https://github.com/gitosphere/homebrew-tap/blob/main/Casks/gsp.rb).
For an older version, use the Cask revision that specified that version.
Do not disable Gatekeeper or strip quarantine attributes to make a failed check pass.

```sh
shasum -a 256 /absolute/path/gsp-VERSION-macos-arm64.dmg
codesign --verify --strict /absolute/path/gsp-VERSION-macos-arm64.dmg
xcrun stapler validate /absolute/path/gsp-VERSION-macos-arm64.dmg
hdiutil attach -readonly -nobrowse /absolute/path/gsp-VERSION-macos-arm64.dmg
```

After checking the volume shown by `hdiutil`, copy its complete contents to a new,
version-specific directory you own. `bin/gsp` is the executable; keep its bundled
`lib` directory alongside `bin` when present. `skills/gsp`, `completions`, and
`docs` must remain available for matching-version setup.
Verify the copied executable with `codesign --verify --strict`, run its absolute
path with `--version --verbose` and `--help`, then detach the volume. Add that directory's
`bin` to PATH deliberately. Copying must preserve executable permissions and
must not re-sign the binary.

For rollback, check the older release's server compatibility first. Stop running
CLI commands, uninstall the Cask if it owns the current executable, and manually
install the older signed DMG into a separate versioned directory. Select its
executable explicitly and replace the Skill and completion files with the same
release's files. Homebrew's ordinary upgrade command follows the current Cask;
manual rollback does not pin a historical Cask automatically. Reauthenticate on
the same host if the older version cannot read the current session format.
