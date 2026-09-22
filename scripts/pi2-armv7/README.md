# scripts/pi2-armv7

Install and verify the `pi` coding agent on a Raspberry Pi 2 Model B (ARMv7). The full write-up —
the decisive facts, the measured results, the acceptance criteria and the two optional code changes —
is in [`docs/armv7-pi2b.md`](../../docs/armv7-pi2b.md).

| Script | Runs on | What it does |
| --- | --- | --- |
| `install-pi-on-pi2.sh` | the Pi2 | gates (arch `armv7l`, not root, a downloader present) → installs Node v22 armv7l into `~/opt` → installs the npm package into `~/.local` → verifies → measures. `--dry-run` changes nothing; `--check-only` inspects only. Fails closed. |
| `pi2-pi-agent.sh` | the PC | `probe` (reachability + current state), `install` (fetches the Node tarball on the PC, scp's it over, runs the installer, keeps a log), `verify` (judges a log against the acceptance list), `all`. Set `HOST=user@host` for your board — it is **required**, there is no default address. |
| `selftest.sh` | the PC | tests the tools themselves, including the paths that must be refused: running the installer on a non-ARMv7 host, `--dry-run` changing nothing, the probe not claiming success when the board is unreachable, and the verifier rejecting a log that shows a non-v22 Node, a stray prebuild, or a root run. |

Notes that matter on this board:

- **No `sudo`.** Everything installs under `$HOME`; the scripts never touch the system.
- **Pin Node to the v22 line.** v22 is the last major with official `linux-armv7l` builds (v23+ have none).
- **Do not assert "no `.node` anywhere".** The npm package bundles x64/arm64/darwin/win32 prebuilds by
  design; on ARMv7 they are simply never loaded. The invariant is "no `prebuilds/linux-arm/` and the CLI
  starts".
- `~/.local` is shared with anything else installed for the user there — remove only the pi pieces when
  rolling back.
