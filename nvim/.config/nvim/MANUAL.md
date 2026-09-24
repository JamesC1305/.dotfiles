# Neovim manual

This guide describes this configuration, not stock Neovim. Start with the first
section; use the rest as a reference. The git history records the changes.

## Contents

- [Start here](#start-here)
- [Navigation and diagnostics](#find-files-navigate-code-and-inspect-diagnostics)
- [Build tasks](#build-and-check-with-overseer)
- [Repository formatting](#format-without-fighting-repository-policy)
- [Rust](#rust-development) and [Python](#python-development)
- [Tests](#run-and-debug-tests-with-neotest)
- [Debugger](#debugger-basics), [logpoints](#logpoints), and [attach](#attach-to-a-running-rust-c-or-c-process)
- [Firecracker workflows](#firecracker-project-workflows)
- [Linux kernel browsing](#cc-and-linux-kernel-browsing)
- [Yank history and clipboard](#yank-history-and-remote-clipboard)
- [Editing helpers](#editing-helpers-and-ui) and [Git](#git-and-github)
- [Maintenance and troubleshooting](#configuration-maintenance-and-troubleshooting)

## Start here

`<leader>` means **Space**. `<localleader>` means **backslash** (`\`).
For example, `<leader>db` means press Space, then d, then b in normal mode.
Capital letters matter: `dO` and `do` are different commands.

Press Space and pause to see which-key's available shortcuts. In a picker,
type to filter, use Ctrl-n/Ctrl-p or the arrow keys to select, and Enter to
confirm. Escape closes an fzf picker. A Snacks text-input prompt can first
leave insert mode on Escape; press Escape again, or `q` in normal mode, to
cancel it.

A useful first session:

1. Open Neovim from a project's root directory.
2. Press `<leader>ff` to find a file or `<leader>sg` to search its contents.
3. Put the cursor on a symbol: `K` shows documentation, `gd` jumps to its
   definition, and Ctrl-o jumps back.
4. Press `<leader>ca` for code actions or `<leader>cr` to rename a symbol.
5. In a test, press `<leader>tr` to run it, then `<leader>to` for output.
6. Press `<leader>oo` to choose a build/check task; `<leader>ow` shows tasks.
7. For Rust debugging, set a breakpoint with `<leader>db`, then choose a target
   with `<leader>dr`. Use `<leader>dc` to continue and `<leader>dt` to end it.
8. Press `<leader>sy` when you need something you yanked earlier.

Restart Neovim after installing these configuration changes. Existing sessions
may still have old plugin options or keymaps loaded.

## Find files, navigate code, and inspect diagnostics

The main picker is **fzf-lua**. The file explorer is **Snacks**. Both choices are
explicit in `lua/config/options.lua`, so they do not depend on LazyVim's old
installation defaults. Content search already uses ripgrep.

| Action | Keys |
| --- | --- |
| Find a file from the project root | `<leader>ff` |
| Search text from the project root | `<leader>sg` |
| Search text from the current working directory | `<leader>sG` |
| File explorer at the project root | `<leader>e` |
| File explorer at the current working directory | `<leader>E` |
| Definition / declaration / implementation | `gd` / `gD` / `gI` |
| References / type definition | `gr` / `gy` |
| Documentation / signature help | `K` / `gK` |
| Signature help while inserting | Ctrl-k |
| Symbols in this file / workspace | `<leader>ss` / `<leader>sS` |
| Outline sidebar (Aerial) | `<leader>cs` |
| Rename symbol with live preview | `<leader>cr` |
| Code action | `<leader>ca` |
| Run / refresh codelens | `<leader>cc` / `<leader>cC` |
| LSP configuration information | `<leader>cl` |
| Diagnostic under the cursor | `<leader>cd` |
| Workspace / buffer diagnostics picker | `<leader>sd` / `<leader>sD` |
| Next / previous diagnostic | `]d` / `[d` |
| Next / previous error | `]e` / `[e` |
| Next / previous warning | `]w` / `[w` |
| Toggle quickfix / location list | `<leader>xq` / `<leader>xl` |

LSP means language server: it supplies type information, navigation, diagnostics,
and semantic edits. Most LSP mappings become useful after a server attaches.
`[c` and `]c` were not repurposed for diagnostics; use `]d` and `[d` instead.

Your additional fzf shortcuts remain:

| Keys | Action |
| --- | --- |
| `<leader>pf` | Browse installed plugin files |
| `<leader>ps` | Live grep using fzf-lua's current context |
| `<leader>pw` | Live workspace-symbol search |
| `<leader>pg` | Git-tracked files |
| `<leader>pr` | Symbol references |
| `<leader>pt` | Treesitter symbols |

The old custom LSP mappings were in an ignored field. Removing them did not
remove working bindings. Use the LazyVim bindings above, rather than the old
`gi`, `gds`, `gws`, `<leader>rn`, or `<leader>aa/ae/aw` definitions.

## Build and check with Overseer

Overseer manages command execution, output, status, cancellation, and reruns.
It does not replace Cargo, Make, pytest, or a project's build scripts.

| Keys or command | Action |
| --- | --- |
| `<leader>oo` / `:OverseerRun` | Choose a discovered task |
| `<leader>ow` | Toggle the task list |
| `:OverseerOpen` | Open the task list |
| `<leader>ot` | Choose an action for a task |

For a Cargo project, choose `cargo check`, `cargo build`, `cargo test`, or
`cargo clippy`. Cargo tasks are discovered from manifests. Make targets and
`.vscode/tasks.json` are also supported. Run from the appropriate project root
if the picker does not find the task you expect.

In the task list:

- Enter opens actions such as `restart`, `stop`, and opening output.
- `o` opens the selected task's output; `p` toggles its preview.
- Ctrl-q sends output to quickfix. Whether file/line entries are useful depends
  on the task's error parser.
- `dd` disposes of the task entry; `q` closes the list, not the running job.
- `?` shows the installed version's task-list bindings.

Use the `stop` action to cancel a running command. `restart` reruns its command;
it is not a debugger restart. Review the command before starting it: discovery
also lists commands such as `cargo clean`, `cargo update`, and `cargo publish`.

Overseer supports DAP `preLaunchTask` in project launch configurations. Ordinary
Rust debugging already builds through rustaceanvim, so do not add another build
step to that route. The existing Firecracker commands now use Overseer too; see
[the Firecracker section](#firecracker-project-workflows).

## Format without fighting repository policy

The normal format shortcut is `<leader>cf`. LazyVim chooses configured Conform
formatters, with LSP formatting as a fallback. Automatic formatting is enabled
by default. The new task and debugger tools do not change formatter choices.

| Action | Command or keys |
| --- | --- |
| Format current buffer or selection | `<leader>cf` |
| Inspect Conform formatter availability | `:ConformInfo` |
| Inspect the complete LazyVim formatting decision | `:lua LazyVim.format.info()` |
| Toggle automatic formatting globally | `<leader>uf` |
| Toggle automatic formatting for this buffer | `<leader>uF` |
| Explicitly disable automatic formatting for this buffer | `:lua vim.b.autoformat = false` |

Use the repository's formatter when it defines one. Ruff formatting is not the
same policy as Black plus isort, and a system rustfmt may differ from a pinned
one. Do not assume enabling a language extra makes it follow every repository's
CI formatting command.

For Firecracker, use `\f` or `:FirecrackerFmt` for its devtool formatter. If you
want only that formatter to touch a buffer, disable its normal autoformat first:
`FirecrackerFmt` saves the file before running devtool, and that save can otherwise
invoke LazyVim's formatter too. Details are below.

## Rust development

The Rust extra supplies **rustaceanvim**, **rust-analyzer**, and **crates.nvim**.
Your workspace-symbol result limit remains 2048.

Useful commands in a Rust buffer:

| Command or keys | Purpose |
| --- | --- |
| `<leader>cR` | Rust grouped code actions |
| `:RustLsp expandMacro` | Inspect macro expansion |
| `:RustLsp explainError` | Explain a diagnostic |
| `:RustLsp openCargo` | Open the relevant Cargo manifest |
| `:RustLsp parentModule` | Navigate to the parent module |
| `:RustLsp runnables` | Choose a target to run without DAP |
| `:RustLsp testables` | Choose a test target to run without DAP |
| `<leader>dr` / `:RustLsp debuggables` | Build and debug a target |
| `:RustLsp debuggables!` | Repeat the last Rust debug target |
| `:RustAnalyzer restart` | Restart rust-analyzer |

In the Firecracker checkout, `<leader>dr` is overridden to `:FirecrackerDebug`
so its build uses devtool. The raw upstream `:RustLsp debuggables` command is not
intercepted; use the project command or Neotest there. Other projects keep the
normal rustaceanvim commands above.

In `Cargo.toml`, crates.nvim provides dependency completion, hover information,
and code actions. Try `K` and `<leader>ca` on a dependency. Taplo also supplies
TOML language support. Registry information requires network access.

The Rust extra enables all Cargo features, build scripts, and proc macros.
Clippy checking on save is enabled when available. On large workspaces these
settings can be expensive; projects with mutually exclusive features may need
project-specific settings rather than `allFeatures = true`.

### Toolchain selection and automatic component installation

The settings hook resolves `rustup which rust-analyzer` from rustaceanvim's
project root and, when successful, launches that exact binary. This avoids
choosing the toolchain solely from the directory where Neovim started.

Separately, the first Rust `FileType` event for each discovered root checks for
the component. If missing, it runs `rustup component add rust-analyzer` in the
background and tells you to run `:RustAnalyzer restart` after success.

This is a once-per-root, per-session check, not a watcher for edits to
`rust-toolchain.toml`. After changing a toolchain during a session, restart
Neovim, or run `rustup component add rust-analyzer` from that repository and
then `:RustAnalyzer restart`.

When resolution fails, the default rustup proxy remains in use. It chooses the
toolchain for the spawned process's working directory. If that toolchain also
lacks rust-analyzer, rustup 1.29+ can use Mason's binary later on PATH. This is a
fallback, not a guarantee that every toolchain, offline setup, or custom compiler
will work immediately.

For repos you control, adding `rust-analyzer` to the existing `components` list
in `rust-toolchain.toml` declares the requirement alongside the toolchain.
Downloads and unavailable components can still fail.

The settings hook preserves rustaceanvim's installed settings loader and the
merged defaults. In the installed version, that loader does not itself read
`.vscode/settings.json` or `.rust-analyzer.json`; earlier review notes overstated
that support. Use explicit rustaceanvim options or a trusted project-local config
for editor settings rather than relying on those files being imported.

## Python development

**basedpyright** provides type checking, hover, navigation, and completion.
**Ruff** provides lint diagnostics, fixes, and LSP formatting. Ruff's hover is
disabled so basedpyright handles documentation.

1. Open a Python file from your project.
2. Press `<leader>cv` (`:VenvSelect`) and select the project's environment.
3. Use `K`, `gd`, `<leader>ca`, and `<leader>cr` as in Rust.
4. Run a nearby pytest test with `<leader>tr`; inspect output with `<leader>to`.
5. Debug the nearest supported test with `<leader>td`, or use `<leader>dc` for
   a Python launch configuration.

The selected environment needs the project's dependencies and test runner.
Installing debugpy through Mason does not install pytest or your project into
that environment. Debugpy's adapter runs from Mason; the debuggee's Python
interpreter is selected separately.

`<leader>dPt` and `<leader>dPc` are the Python extra's method/class debug keys.
Use `<leader>td` when you want Neotest to discover and debug a pytest test.
Type-checker and Ruff rules belong in project configuration such as
`pyproject.toml` and `pyrightconfig.json`, not in global per-project exceptions.

## Run and debug tests with Neotest

| Keys | Action |
| --- | --- |
| `<leader>tr` | Run nearest test |
| `<leader>tt` | Run current file |
| `<leader>tT` | Run tests from the working directory; potentially expensive |
| `<leader>tl` | Run last test again |
| `<leader>td` | Debug nearest test through DAP |
| `<leader>ts` | Toggle test summary |
| `<leader>to` | Open test output |
| `<leader>tO` | Toggle output panel |
| `<leader>tS` | Stop a test run |
| `<leader>tw` | Toggle watching the current file |

Rust uses rustaceanvim's adapter; Python uses neotest-python. This is not a
replacement for repository-specific integration harnesses that start containers,
require root, fetch VM images, or provision networking. Use their commands through
Overseer or a terminal instead.

## Debugger basics

DAP is the Debug Adapter Protocol. **nvim-dap** controls a debugger, **CodeLLDB**
debugs native Rust/C/C++ programs, and **dap-ui** displays variables, stacks,
breakpoints, and the debugger console. Python uses debugpy.

### Launch a Rust target

1. Open a source file and wait for rust-analyzer to attach.
2. Put the cursor on an executable line and press `<leader>db`.
3. Press `<leader>dr` and choose a target. Rustaceanvim builds it and locates
   the executable from Cargo's artifact output.
4. When stopped, inspect scopes in dap-ui, hover with `<leader>dw`, or evaluate
   with `<leader>de`.
5. Step or continue using the table below.

Arguments are supported, for example:

```vim
:RustLsp debuggables --api-sock /tmp/my-debug.sock --no-seccomp
```

Select the appropriate binary rather than a test entry. This example's flags are
Firecracker flags, not generic Rust flags.

### Session controls

| Keys | Action |
| --- | --- |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Set conditional breakpoint |
| `<leader>dL` | Set a logpoint; new in this configuration |
| `<leader>dc` | Choose a launch/attach configuration, or continue current session |
| `<leader>da` | Run with argument prompt |
| `<leader>dO` | Step over |
| `<leader>di` | Step into |
| `<leader>do` | Step out |
| `<leader>dC` | Run to cursor |
| `<leader>dP` | Pause |
| `<leader>dk` / `<leader>dj` | Move up / down the call stack |
| `<leader>dl` | Run last DAP configuration |
| `<leader>dt` | Terminate session |
| `<leader>du` | Toggle dap-ui |
| `<leader>de` | Evaluate word or visual selection |
| `<leader>dw` | Variable hover widget |

`<leader>dr` is Rust's debug-target picker in Rust buffers, but toggles the DAP
REPL in other buffers. To open the REPL explicitly from Rust:

```vim
:lua require("dap").repl.open()
```

### Logpoints

A logpoint prints a message and continues instead of stopping. Put the cursor
on a line, press `<leader>dL`, and enter a message such as:

```text
count={count}
```

The expression must be in scope at that line. Look for the output in the DAP
REPL/console. An empty message or cancelled prompt leaves the existing breakpoint
unchanged. Setting a logpoint replaces the breakpoint at that line; use
`<leader>db` to remove it.

Logpoints still interrupt execution internally and evaluate expressions. Do not
use them as zero-overhead tracing or to measure timing-sensitive behaviour.

### Attach to a running Rust, C, or C++ process

1. Start your debug build normally in a terminal or through your harness.
2. Open its Rust/C/C++ source in Neovim.
3. Press `<leader>dc`, select **Native: Attach to process** in Rust, or the
   existing **Attach to process** in C/C++, then filter by process name or PID.
   Confirm the PID before pressing Enter.
4. Set breakpoints, continue or pause, and inspect the running program.

This generic entry does not build, restart, or elevate the target. Keep debug
symbols and matching source available. Optimised binaries can skip source lines
or optimise variables away.

The extra native provider stays hidden when the filetype already has a CodeLLDB
attach configuration. This keeps the C/C++ picker from showing duplicate choices.

To detach and explicitly leave the target running:

```vim
:lua require("dap").disconnect({ terminateDebuggee = false })
```

Use this rather than terminate when you want the process to survive. Cancelling
the process picker aborts the new session.

Linux attach permission depends on ownership, dumpability, Yama `ptrace_scope`,
capabilities, namespaces, and whether another debugger is attached. The picker
can show processes you are not allowed to debug. This setup does not bypass
those restrictions or attach to root-owned processes as an ordinary user.

## Firecracker project workflows

The checkout's trusted `.nvim.lua` activates helpers stored beside it in `.nvim/`.
Both are git-excluded in that checkout. An inactive copy of the complete setup is
saved in this config's `project-configs/firecracker/` directory for reuse on another
machine. Start Neovim from the Firecracker checkout to load its local commands.

Editing `.nvim.lua` invalidates its trust entry. Review the file, open it in
Neovim, and run `:trust` if you approve it, then restart Neovim from the checkout.
This update does not automatically grant trust to the edited file.

If `<leader>dc` does not show the Firecracker choices, open `.nvim.lua`, review
the code, and run `:trust`, then restart from the checkout.
`:verbose nmap <leader>dc` should show LazyVim's normal `Run/Continue` mapping.
It collects the registered Firecracker choices alongside other DAP configurations
and `launch.json` entries. A stale trust entry prevents project setup from loading;
installing DAP alone cannot supply these project launch configurations.

### Repeated prompts or an accidental denial

Approval is remembered for the exact `.nvim.lua` contents. Editing that file
invalidates its approval. Choosing **Ignore** does not approve it, so the prompt
returns next time; choosing **Deny** stores a denial and skips the file until you
change that decision.

To recover from inside Neovim at the Firecracker root:

```vim
:edit .nvim.lua
:trust ++remove
```

Review `.nvim.lua` and the `.nvim/` helpers it loads. If you approve them, with
`.nvim.lua` still in the current buffer, run:

```vim
:trust
```

Then restart Neovim from the checkout. Alternatively, after clearing the denial,
choose **View** at the startup prompt and run `:trust` in that file's buffer.
The installed Neovim version does not offer a direct Allow choice for files.
Once approved, an unchanged `.nvim.lua` should load without asking on each start.
Trust applies to the entry file; helpers loaded with `dofile` are not separately
hash-checked, so review them too when updating the saved setup.

To confirm project loading after restarting, run `:echo exists(':FirecrackerDebug')`.
It should print `2`. If it prints `0`, check `:set exrc?`, `:pwd`, and `:messages`.

### Restore this setup on another machine

The saved copy contains `.nvim.lua` and all four `.nvim/` helper files. Restore
both; `.nvim.lua` alone is not enough. These files are not automatically loaded
from `project-configs/` and are not automatically synchronised with a checkout.
The **live Firecracker checkout is the working copy to edit**. The copy in
`project-configs/firecracker/` is a portable snapshot, not a second active config.

After installing this Neovim config and its plugins, copy the files into your
Firecracker checkout. Set the paths below for the new machine. The `-i` option
asks before replacing an existing file, so you can preserve local edits.

```sh
NVIM_CONFIG="$HOME/.config/nvim"
FIRECRACKER="/path/to/firecracker"
cp -ai -- "$NVIM_CONFIG/project-configs/firecracker/.nvim.lua" "$NVIM_CONFIG/project-configs/firecracker/.nvim" "$FIRECRACKER/"
```

If you use a custom Neovim config location, `:echo stdpath('config')` shows it.
The project root is derived from the copied `.nvim.lua`; no username or checkout
path needs editing. Copy the files rather than symlinking them to the saved copy.

Keep the local editor files out of Firecracker changes by adding these patterns
to the checkout's Git exclude file (`.git/info/exclude` for a regular clone):

```gitignore
/.nvim.lua
/.nvim/
```

For a linked worktree, `git rev-parse --git-path info/exclude` from the checkout
locates that file. Then review the restored `.nvim.lua` and `.nvim/` helpers, open
`.nvim.lua` in Neovim, run `:trust`, and restart from the checkout.

Docker access, the devtool image, CodeLLDB, and the enabled language/test extras
are still required. This copy does not include containers, build caches, VM
artifacts, installed plugins, or trust records. Check the instructions against
the new checkout's devtool interfaces before running it.

After editing and testing the live checkout's hooks, refresh the saved snapshot
with the same variables defined above:

```sh
cp -ai -- "$FIRECRACKER/.nvim.lua" "$FIRECRACKER/.nvim" "$NVIM_CONFIG/project-configs/firecracker/"
```

Review the snapshot diff before committing it with your dotfiles. If you delete
or rename a helper in the live checkout, remove its obsolete saved counterpart
too: these copy commands update files but do not delete stale files.

### Container lifecycle and prerequisites

The first test or debug build starts an editor-owned container through the
checkout's `tools/devtool sh`. It uses devtool's image, repository mount, Cargo
caches, and privileges. Later commands use `docker exec` in that same container.
No debug port is published: Python's debug adapter uses stdio through Docker.

You need working Docker access and the devtool image available. `devtool sh`
runs privileged containers in this checkout; this is the same privilege as
running that command yourself, not an unprivileged sandbox. The integration does
not alter host ptrace/KVM settings or run `devtool test --performance`.

`:DevtoolStop` asynchronously stops this editor's container. The next run starts
a fresh one. A keeper detects Neovim exit and tears it down without blocking the
editor's exit. Stopping the container cancels commands still running in it.
Existing compiled artifacts stay in the repository's build cache.

Editor runner copies, test reports, and logs live under
`build/.nvim-devtool/<editor-pid>/`. Retained reports can be removed after stopping
the container. Do not remove a live session's directory. Each Cargo command restores
ownership of `build/cargo_target` to your host UID/GID before reporting completion,
including failed and cancelled builds. Container teardown also repairs ownership.
`tools/devtool fix_perms` remains the repository's manual repair command.

The image contains pytest and project Python dependencies but not debugpy. First
Python debugging use installs the Mason debugpy version with container Python into
`build/.nvim-devtool/python/`. That cache is keyed by version, Python ABI, and
machine architecture, not editor PID. Later sessions reuse it. Setup runs
asynchronously and does not modify host Python or the image. An initial install
needs package-index access; ordinary pytest does not need debugpy.

### Run and debug tests

The existing Neotest shortcuts stay the same:

| Keys | Firecracker behavior |
| --- | --- |
| `<leader>tr` / `<leader>tt` | Run nearest test / current file inside devtool |
| `<leader>td` | Debug nearest test using the devtool-backed adapter |
| `<leader>ts` / `<leader>to` | Test summary / output |
| `<leader>tS` | Stop the current test run |
| `<leader>dr` in Rust | Choose a Rust binary or test, build through devtool, then debug |
| `:FirecrackerDebug!` | Repeat the last selected devtool Rust target |

Python uses the container interpreter, not `<leader>cv`'s host virtualenv.
Both pytest execution and Python DAP reuse `tools/test.sh` for the repository's
cgroup setup, artifact copy, TMPDIR, and tests working directory. Neotest's result
runner replaces only the final pytest entry point. Selected node IDs, result
files, and breakpoint paths are translated between the host and `/firecracker`.
`<leader>dPt` debugs the nearest Python test. `<leader>dPc` debugs its enclosing
test class, or reports that no test class is under the cursor.

This is an editor test run, not all of `tools/devtool test`: it does not download
missing artifacts, reload KVM modules, or build the full release workspace for
you. Before VM integration tests, prepare the artifacts and binaries as you
normally do with devtool. Current artifacts are copied into the container by
`tools/test.sh`. Later runs reuse `/srv/test_artifacts` in the same container using
`FC_TEST_SKIP_ARTIFACT_COPY=1`; changing `build/current_artifacts` triggers another
copy. If files change in place under the same artifact selection, use
`:DevtoolStop` before the next run to refresh them. Missing VM prerequisites surface
as real pytest errors.

Rust test discovery still uses the host rust-analyzer. Wait for it to finish
loading the workspace before running a newly opened test. Test execution and
debug compilation run in devtool with the native `*-unknown-linux-musl` target
unless a runnable explicitly supplies another target. Normal Rust tests execute
in the container; Rust DAP launches the shared, statically linked test executable
with host CodeLLDB and a `/firecracker` source map. The LSP's background checking
remains on the host. No global analyzer cache override is set; a Cargo lock wait
can still occur while another build/check uses the same cache. Host-only toolchain
environment paths are not forwarded to container Cargo.

Project-wide background Neotest discovery is disabled; the Rust adapter ignores
build caches/resources and accepts source files only under `src/`. Open a test file
and allow rust-analyzer to finish loading before running it. Python runs share a
container lock so preparation cannot overwrite artifacts used by another run.
Cancellation sends an interrupt and allows five seconds for teardown before
escalating. `:DevtoolStop` also cancels a Rust debug compilation that is still
preparing its DAP configuration.

### Repository formatting and checks

| Command | What runs |
| --- | --- |
| `\f` / `:FirecrackerFmt` | Format through devtool: Python uses Black plus isort with `tests/pyproject.toml`; Rust runs `cargo fmt --all`; Markdown uses mdformat |
| `:FirecrackerFmtAll` | Save buffers, then `tools/devtool fmt` |
| `:FirecrackerCheckStyle` | `tools/devtool checkstyle` |
| `:FirecrackerCheckBuild` | `tools/devtool checkbuild` |

These commands run registered Overseer templates. Inside the checkout,
`<leader>oo` also lists **Firecracker: format all**, **Firecracker: check style**,
and **Firecracker: check build**. With a named Python/Rust/Markdown file open,
it also lists **Firecracker: format current file**. The task captures the source
buffer before the picker opens, so formatting does not target the picker itself.

Use `<leader>ow` to see output/status and Enter for restart or stop. Formatting
runs reload externally changed files afterwards. Failures populate quickfix.
These templates are scoped to the checkout and still need devtool's normal
container/runtime prerequisites. The picker and commands use the same templates;
there is no second set of build or formatter commands to maintain.
Registration is once per checkout per Neovim session, so re-sourcing `.nvim.lua`
does not duplicate its task choices. Restart Neovim after changing task definitions
to load the new definitions.

`FirecrackerFmt` saves the current file. Rust formatting affects the workspace,
not just that buffer. Disable ordinary autoformat with
`:lua vim.b.autoformat = false` first if you want only devtool's formatter to run.

### Launch the VMM

In a Rust buffer, `<leader>dc` offers:

- **Firecracker: boot from config file**: asks for a VM config JSON and launches
  with `--no-api --no-seccomp --config-file <path>`.
- **Firecracker: API socket (/tmp/firecracker-dbg.sock)**: launches with that
  socket and `--no-seccomp`; send API requests from another terminal.

Both compile through the devtool-created container for the native musl target as
an Overseer task, then launch the shared binary with host CodeLLDB. Cargo's JSON
artifact output supplies the executable path; container paths are mapped to the
host checkout. Terminal colour/progress is disabled. The package's library
artifact has no executable and is ignored. Failed or cancelled builds abort the
launch; inspect their output in Overseer. Rerunning only the build task does not
start another debug session.

The API launch deletes its configured socket path before starting. Do not use
that fixed path for another active instance. Use `:FirecrackerDebug` with your
own arguments when you need separate sockets or a one-off launch, for example
`:FirecrackerDebug --api-sock /tmp/my-fc.sock --no-seccomp`.

These launch entries disable seccomp for debugging. Debugger evaluation that
calls functions can make syscalls outside the VMM's allowed filters. Do not use
`--no-seccomp` when validating production seccomp behaviour. Merely reading a
variable is not equivalent to executing a function in the target.

The host must provide KVM access, guest kernel/rootfs images, and any network
setup you need. Do not assume `/dev/kvm` permissions are identical on every host.
Creating/configuring TAP devices requires suitable privileges; a pre-created TAP
owned by your user can avoid running the VMM as root. Jailer and container-based
integration workflows need their own permissions and debugger setup.

The `/firecracker` to checkout source map is now configured for container-built
Rust artifacts. Host CodeLLDB still launches the VMM as your user; it does not
launch the jailer inside the privileged container. In a Python buffer,
`<leader>dc` offers **Firecracker: debug Python tests (devtool)**. It launches
`python -m pytest` on the file, not the file as a plain Python script.
Use `<leader>td` when you want only the nearest test.

## C/C++ and Linux kernel browsing

clangd prefers Mason's installed binary by explicit path, with the PATH version
as fallback when that binary is absent. Background indexing is explicitly
configured. The installed upgrade was clangd 23.1.0; `:Mason` shows later updates.

For the kernel, a usable `compile_commands.json` matters more than extra editor
plugins. Build/configure the target tree and use its
`scripts/clang-tools/gen_compile_commands.py` to generate the database. For
out-of-tree builds, point clangd at the correct build directory. Consult the
script's `--help` for that checkout's arguments.

clangd indexes the translation units in the compilation database. It cannot
infer every kernel configuration at once. The first index can take time and
CPU; `-j` currently uses available CPU parallelism. Existing background indexing
is normally enabled by clangd itself too, so the explicit flag makes the intent
clear rather than being the sole source of project-wide navigation.

Use `gd`, `gr`, `<leader>cr`, and `<leader>ch` (switch source/header). The existing
`--query-driver` allowlist lets matching compiler drivers supply system include
paths and target information. A cross-compiler outside that allowlist needs an
explicit trusted entry; this flag permits clangd to execute matching drivers.

## Yank history and remote clipboard

Normal `y`, `p`, and `P` use Yanky. It keeps a ring of recent yanks/deletions and
preserves the cursor when yanking.

| Keys or command | Action |
| --- | --- |
| `<leader>sy` / `:YankyRingHistory` | Pick an earlier entry and paste it |
| `p` / `P` | Paste after / before |
| `[y` | Cycle the last paste toward older history |
| `]y` | Cycle back toward newer history |
| `]p` / `[p` | Paste with indentation adjustment |
| `:YankyClearHistory` | Clear Yanky's history |

Try yanking two different lines, paste with `p`, then press `[y` to replace that
paste with the older one. Cycling applies to the last paste; other editing can
end the cycle. `<leader>p` is deliberately unbound, so your `<leader>pf/ps/...`
picker shortcuts remain unaffected.

Default history holds up to 100 entries and uses ShaDa persistence. Yanky also
synchronises numbered registers with history, which changes the usual deletion
register behaviour. Do not copy secrets if you do not want them retained.
Clearing Yanky's history is not a secure erase of system clipboard or other
registers. The black-hole register (`"_d`) avoids recording that deletion.

Your OSC 52/tmux clipboard setup is unchanged. Yanks can reach the local terminal
clipboard across SSH/mosh; terminal support is required. Remote clipboard reads
may be unsupported or slow. Yank history is local editor history, not a guarantee
that the terminal can return its clipboard. LazyVim disables Yanky's clipboard
ring synchronisation under SSH.

## Editing helpers and UI

- `<leader>cr`: live LSP rename preview. Edit the proposed name and press Enter;
  Escape cancels. Review cross-file edits before saving.
- `<leader>cn` / `:Neogen`: generate a function's annotation/doc-comment
  skeleton, then fill it in. Generated text is a starting point, not verified
  documentation.
- `<leader>rs`: refactoring picker; visual selections help define the target.
  `<leader>rf` extracts a function, `<leader>rx` extracts a variable, and
  `<leader>ri` inlines a variable where the language backend supports it.
  Prefer rust-analyzer's `<leader>ca` for Rust semantic refactoring.
- `<leader>H` bookmarks a file with Harpoon; `<leader>h` opens its list;
  `<leader>1` through `<leader>9` jump to bookmarked files.
- `<leader>cs` opens Aerial's symbol outline. Treesitter context keeps enclosing
  definitions visible while scrolling.
- `<leader>U` opens Undotree. Ordinary undo remains `u`; redo is Ctrl-r.
- vim-surround remains installed: for example, `ysiw"` surrounds a word with
  quotes and `cs"'` changes double quotes to single quotes. mini-surround was
  not enabled.
- The colour scheme is Kanagawa. Lualine uses LazyVim's sections again, including
  Noice status information such as macro recording. Smooth scrolling stays off.
- TOML, JSON, YAML, and Markdown extras supply their language/editor support.
  Schema help depends on recognised filenames/schema associations; it does not
  validate every arbitrary configuration file automatically.

## Git and GitHub

| Keys | Action |
| --- | --- |
| `<leader>gb` | Git line-history/blame picker |
| `<leader>gB` | Browse repository location in the browser |
| `<leader>ghb` / `<leader>ghB` | Gitsigns line / file blame |
| `<leader>gi` / `<leader>gI` | Open / all GitHub issues |
| `<leader>gp` / `<leader>gP` | Open / all GitHub pull requests |

Current-line blame remains enabled. The old gitsigns overrides were removed so
`gb` and `gB` keep LazyVim's meanings. GitHub pickers and dashboard PR/issue lists
need the GitHub CLI and repository access. Selecting actions that comment, merge,
or open remote resources is separate from local browsing.

## Configuration, maintenance, and troubleshooting

| Location or command | Purpose |
| --- | --- |
| `lazyvim.json` / `:LazyExtras` | Enabled LazyVim extras |
| `lua/config/options.lua` | Clipboard, project config support, picker/explorer and Python LSP choices |
| `lua/config/autocmds.lua` | Rust component check and existing lockfile auto-commit hook |
| `lua/plugins/lspconfig.lua` | clangd command and Rust settings hook |
| `lua/plugins/mason.lua` | Mason PATH policy and added tools |
| `lua/plugins/dap.lua` | Generic logpoint mapping and native attach provider |
| `lua/plugins/yanky.lua` | History shortcut without `<leader>p` conflict |
| Project `.nvim.lua` | Trusted repository-specific commands |
| Project `.nvim/` | Firecracker-local test adapters, container transport, and setup |
| `project-configs/firecracker/` | Inactive, complete Firecracker editor setup saved for restoration |
| `:Lazy` | Plugin manager |
| `:Mason` | External servers, formatters, and debugger tools |
| `:checkhealth` | Environment checks |
| `:messages` | Recent editor messages |
| `:help dap` / `:help overseer` / `:help yanky` | Installed plugin documentation |

Mason appends its bin directory to PATH. Existing toolchain/project tools win
normal executable lookups. clangd is an intentional exception because its command
uses Mason's absolute path. Shell selection of a Python virtualenv and DAP's
interpreter selection are separate; inspect the active project environment when
imports fail.

To add a missing Mason tool, open `:Mason` first, then use its UI or
`:MasonInstall <package-name>`. Loading Mason matters when using its other
commands in a fresh session. Restart an affected language server after changing
its binary; restarting Neovim is the simplest way to reload all configuration.

### Update warning

An existing `User LazyUpdate` hook automatically stages the lockfile and runs an
ordinary `git commit`. It also sets the repository Git identity. Such a commit
can include other changes already staged in the same repository. That hook was
not rewritten here. Avoid `:Lazy update`/`:Lazy sync` until you have reviewed
`lua/config/autocmds.lua` and your staged changes; remove the hook yourself or
request its removal if you want all commits to remain manual.

`:Lazy install` installs missing plugins; `:Lazy clean` deletes unused plugin
directories. Neither is a substitute for reviewing the config or lockfile. No
changes from this workflow were intentionally staged or committed.

### Common problems

| Symptom | First check |
| --- | --- |
| New shortcut missing | Restart Neovim; open the relevant filetype; use `:verbose nmap <leader>dL` or the relevant key |
| Firecracker commands missing | Start from the checkout; review and re-trust its changed `.nvim.lua` |
| Project trust prompt repeats or commands disappear after Deny | See [trust recovery](#repeated-prompts-or-an-accidental-denial): clear the denial, view `.nvim.lua`, run `:trust`, then restart |
| Rust component install failed | Read notification; run `rustup component add rust-analyzer` in the repo; restart the server |
| Rust server stays on an old toolchain | The check is not a file watcher; restart Neovim after changing the pin |
| Python imports unresolved | `<leader>cv`, project dependencies, and basedpyright settings |
| No tests found | Supported adapter, test naming, project environment, and correct working directory |
| Task missing | Correct project root/manifest; unsupported custom commands need a project task definition |
| Breakpoint unverified | Matching binary/source, debug symbols, executable line, and optimisation level |
| Attach denied | Confirm PID, ownership, ptrace policy, container namespace, and other debuggers |
| Failed/cancelled Firecracker build | `<leader>ow`, inspect output; no debuggee should start |
| Paste cycling does nothing | Paste with Yanky's `p` first, then immediately use `[y`/`]y` |
| Clipboard paste waits | Terminal OSC 52 read support; use terminal paste or editor history |
| Formatting differs from CI | Inspect formatter, disable buffer autoformat, then use repo devtool command |
| Devtool container fails to start | Docker access, available devtool image, and `build/.nvim-devtool/<pid>/container.log` |
| Python debug dependency setup fails | Container package-index access and the versioned debugpy cache under `build/.nvim-devtool/python/` |
| Cargo waits on a build lock | Another Cargo build or rust-analyzer check may hold the cache lock; wait for it or stop that operation. Ownership repair is separate from lock contention. |
| Hunk markers differ from earlier experiments | The custom gutter experiment was reverted; Gitsigns and LazyVim's original markers/layout are active |

## What was verified

The new workflows were exercised in a real Neovim TUI with the installed config:
Cargo task discovery/check/rerun; history picker and paste cycling; logpoint
interpolation; native process picker and attach; breakpoint stop; detach leaving
the target alive; Firecracker Cargo build through Overseer and a breakpoint in
`firecracker::main`; and failed/cancelled Cargo builds aborting DAP launches.
The project formatting/check command arguments were preserved; broad devtool
formatting and full integration suites were not run as part of this update.
Follow-up checks confirmed the Firecracker tasks appear in `<leader>oo` only in
the checkout, C/C++/Rust each offer one native attach configuration, and the real
Firecracker breakpoint still hits with the Cargo task's nonterminal output mode.
The devtool cutover was tested separately: a real Firecracker pytest test passed
normally and under Python DAP with a source breakpoint; a real Rust unit test
passed under Neotest DAP after a devtool musl build; the VMM launch hit
`firecracker::main` from the musl artifact. Pass/fail/skip reporting was exercised
with a throwaway Python test, and cancellation terminated an owned in-container
process. This did not run the full privileged VM integration suite.
Hardening checks covered cache reuse across container restarts, artifact-copy reuse,
whole-class Python debugging, `pytest` file launching, graceful cancellation with
fixture-like teardown, and host ownership after successful/failed/cancelled Cargo
jobs. The original gutter configuration was checked against the committed version;
no alternate hunk layout remains.
The empty-environment follow-up found and fixed a second JSON-shape issue in the
CodeLLDB launch configuration. After the fix, a fresh `<leader>td` run stopped in
`utils::validators::tests::test_validate_instance_id` at `validators.rs:42`, then
exited 0 with Neotest reporting one pass. A runnable whose only environment entry
was `RUSTC_TOOLCHAIN` also ran successfully through devtool after filtering;
both the container environment and the DAP environment encoded as `{}`.

The guide describes other features enabled earlier in this session as well.
Not every key in this reference was independently exercised again. Repository
formatting policies, privileged networking, guest boot, and container attach must
still be checked for the particular project or machine you use.
