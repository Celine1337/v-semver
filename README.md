<p align="center">
  <img src="assets/banner.svg" width="830" alt="v-semver banner">
</p>
<p align="center">
  <a href="https://github.com/Celine1337/v-semver/releases"><img src="assets/nav-releases.svg" alt="Releases"></a>
  <a href="https://semver.org/spec/v2.0.0.html"><img src="assets/nav-spec.svg" alt="SemVer 2.0.0"></a>
  <a href="LICENSE"><img src="assets/nav-mit.svg" alt="MIT"></a>
</p>

<img src="assets/section-about.svg" width="830" alt="About">

**v-semver** is a tiny [SemVer 2.0.0](https://semver.org/spec/v2.0.0.html) multitool for the shell: `compare` prints `-1`, `0` or `1` for two versions, `bump` increments major/minor/patch (dropping prerelease and build metadata), and `valid` checks strict spec syntax. Precedence follows the spec exactly — numeric core comparison, prerelease versions ranking below their release, identifier-by-identifier prerelease ordering (numeric vs alphanumeric, fewer fields vs more), and build metadata ignored for precedence.

Why V? Because it produces a small, fast, dependency-free native binary from one readable source file. Numeric components are compared as validated decimal strings, so even absurdly large versions compare correctly without integer overflow — and invalid input is rejected with precise stderr messages instead of silent garbage.

<img src="assets/section-features.svg" width="830" alt="Features">

- **Spec-exact precedence** — implements the full semver.org ordering chain, including `1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0`.
- **Identifier rules** — numeric identifiers compared numerically (`alpha.2 < alpha.10`), numeric < alphanumeric, lexical ASCII otherwise, fewer fields < more when all equal.
- **Build metadata ignored** — `1.0.0+build1` and `1.0.0+build2` have equal precedence, as the spec requires.
- **Strict validation** — rejects leading zeros (`01.2.3`, `1.2.3-01`), empty identifiers (`1.2.3-alpha..1`), dangling separators, bad characters and wrong field counts.
- **Big-number safe** — core components compared as decimal strings; no 64-bit overflow on compare.
- **Clean bumps** — `bump 1.2.3-alpha+build patch` → `1.2.4`; minor/major reset lower fields.
- **Scriptable exit codes** — `0` success/valid, `1` invalid version input, `2` bad usage; errors on stderr.
- **Tested** — 63 self-contained shell assertions on exact outputs and exit codes.

<img src="assets/section-stack.svg" width="830" alt="Tech stack">

<img src="assets/section-install.svg" width="830" alt="Install">

Requires [V](https://vlang.io/) 0.5.2+ to build; the resulting binary has no runtime dependencies.

```bash
git clone https://github.com/Celine1337/v-semver.git
cd v-semver
./build.sh          # v -o bin/v-semver src/main.v
./bin/v-semver compare 1.2.3 1.2.4
```

<img src="assets/section-usage.svg" width="830" alt="Usage">

```bash
v-semver compare <A> <B>                 # -1, 0 or 1
v-semver bump <ver> <major|minor|patch>  # bumped version
v-semver valid <ver>                     # valid/invalid, exit 0/1

v-semver compare 1.0.0-alpha.2 1.0.0-alpha.10   # -1 (numeric, not lexical)
v-semver compare 1.0.0+build1 1.0.0+build2      # 0  (build ignored)
v-semver bump 1.2.3 minor                       # 1.3.0
v-semver valid 01.2.3                           # invalid, exit 1
```

```text
$ v-semver compare 1.0.0-rc.1 1.0.0
-1
$ v-semver bump 1.2.3-alpha+build patch
1.2.4
$ v-semver valid 1.2.3-x.7.z.92
valid
```

Exit codes: `0` success / valid version, `1` invalid version input (`compare`/`bump`) or invalid version (`valid`), `2` bad usage.

<img src="assets/section-license.svg" width="830" alt="License">

MIT — see [LICENSE](LICENSE).