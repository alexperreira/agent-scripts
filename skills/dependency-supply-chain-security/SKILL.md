---
name: dependency-supply-chain-security
description: >
  Reviews third-party packages for known CVEs, overly broad permissions, and abandonment risk.
  Use this skill whenever Alex is adding a new npm or pip package, reviewing a dependency
  update, asking "is this package safe to use", "should I use X or Y library", or auditing
  an existing project's dependencies. Also trigger proactively when a task doc adds new
  packages, or when reviewing code that installs dependencies without version pinning. Supply
  chain attacks via malicious or compromised packages are a growing vector — every new
  dependency is a trust decision.
---

# Dependency & Supply Chain Security

Evaluates third-party packages for security risk, maintenance health, and supply chain
integrity before adding them to a project.

---

## Red Flags

Immediate disqualifiers for adding a package — check these before anything else:

- **CVE with no patch available** — find an alternative
- **Typosquatting risk** — `lodash` vs `1odash`, `express` vs `expres`; verify package name
  carefully before installing
- **Postinstall script that phones home** — any `postinstall` that makes network requests
  without clear justification
- **Recently transferred ownership** — new owner of an established package is a common
  supply chain attack vector
- **Minified-only source with no readable code** — can't audit what you can't read

**When the package is a React Native module, an Expo config plugin, or a browser extension,
read `references/manifest-permissions.md` — permission review (camera, contacts, location,
filesystem) belongs to those package types. npm and pip libraries declare no manifest
permissions; for those, the Scope & Permissions checklist below is the whole permission review.**

---

## Core Principles

1. **Every dependency is a trust decision.** Adding a package means trusting its author,
   its release pipeline, and every package it depends on transitively. It runs with full
   application privileges. Evaluate accordingly.

2. **Prefer smaller, focused packages over large frameworks for critical paths.** A 50-line
   utility you own is safer than a 50,000-line framework you don't — for security-critical
   functions (crypto, auth, input parsing). Cryptographic primitives are the exception: use a
   well-vetted library.

3. **Pin versions in production.** `^1.2.3` allows minor/patch updates automatically.
   `1.2.3` pins exactly. Production installs run `npm ci` against a committed lockfile
   (`package-lock.json`, `poetry.lock`).

4. **Audit regularly, not just at install time.** CVEs are discovered after packages are
   published. Schedule periodic audits — at minimum before each production release.

---

## Package Evaluation Checklist

Before adding any new package, evaluate:

### Popularity & Maintenance
- [ ] Weekly downloads: > 100k/week is a healthy signal for general packages
- [ ] Last publish date: packages not updated in 2+ years are abandonment risk
- [ ] Issue backlog: > 3 open issues labeled `security`, or any security issue open > 90 days
- [ ] Maintainer count: single-maintainer packages are higher supply chain risk
- [ ] GitHub stars and forks: directional signal, not definitive

### Security Posture
- [ ] Known CVEs: check [Snyk Advisor](https://snyk.io/advisor) and
  [npm audit](https://docs.npmjs.com/cli/v9/commands/npm-audit) / `pip-audit`
- [ ] Security policy: does the repo have a `SECURITY.md`?
- [ ] Recent suspicious releases: any release in the last 90 days that adds a maintainer, adds a
  `postinstall`/`preinstall` script, or grows the published tarball by > 20%?
- [ ] Dependency count: a package with 200 transitive dependencies has 200 trust decisions embedded

### Scope & Permissions
- [ ] Does this package need network access for what you're using it for?
- [ ] Does it read the filesystem beyond what the use case requires?
- [ ] Does it shell out (`exec`, `spawn`) unexpectedly?
- [ ] Does the package declare any install script at all? If yes, read it in full and quote it
  in the report.

---

## Running Audits

Run `npm audit` / `pip-audit`; gate on zero high or critical.

### GitHub Dependabot
Enable in `.github/dependabot.yml` for automated PR creation on vulnerable dependencies:
```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

---

## Lockfile & Version Hygiene

```bash
# Always commit lockfiles
git add package-lock.json  # or yarn.lock, pnpm-lock.yaml

# Use exact versions for security-critical packages
npm install --save-exact jsonwebtoken bcrypt

# Check for peer dependency conflicts after installs
npm ls 2>&1 | grep -i "peer dep"

# Identify unused dependencies periodically
npx depcheck
```

---

## Audit Checklist for Existing Projects

Run this periodically (before major releases, quarterly):

- [ ] `npm audit` / `pip-audit` — zero high/critical vulnerabilities
- [ ] Every package in the tree is free of published CVEs
- [ ] Lockfile committed and up to date
- [ ] `node_modules` in `.gitignore`
- [ ] Every dependency installs cleanly without `--force` or `--legacy-peer-deps`
- [ ] Production installs run `npm ci` against a committed lockfile
- [ ] Dependabot or equivalent automated scanning enabled
- [ ] Unused packages removed (`depcheck` or equivalent)

---

If a package clears the red flags and the evaluation checklist, say so clearly and record the
trust decision — don't manufacture concerns.
