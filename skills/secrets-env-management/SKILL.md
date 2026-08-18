---
name: secrets-env-management
description: >
  Audits env var handling, .env hygiene, secret rotation patterns, and what should never be in
  version control. Use this skill whenever Alex is setting up a new project, adding a new
  integration that requires API keys or credentials, asking "how should I store this secret",
  "is this safe to commit", "how do I rotate this key", or reviewing code that touches
  environment variables. Also trigger proactively when a task doc introduces a new third-party
  integration, a new service credential, or any value that differs between environments.
  A single leaked secret in git history can compromise an entire system — and git history is
  forever.
---

# Secrets & Environment Management

Ensures secrets are handled safely: correctly scoped by environment, rotatable without
downtime, auditable, and present in source control only as placeholders.

---

## If a secret has leaked

**Rotate first, scrub second. A scrubbed history with an unrotated key is still a live
compromise.**

1. **Rotate the credential at the provider immediately.** Treat the old value as already
   compromised — assume it was scraped the moment it was pushed.
2. **Then remove it from git history** with `git filter-repo` or BFG Repo Cleaner, and force-push.
3. **Then check the provider's audit log** for use of the old credential between the leak and
   the rotation.

---

## The Cardinal Rules

1. **Secrets reach the process through exactly two paths: the environment, or a secrets
   manager.** Source control holds placeholders only. Git history is permanent and often more
   accessible than it appears.

2. **`.env.example` is the contract.** It lists every variable the app needs, with placeholder
   values and a comment describing what each is. It lives in source control; the real `.env`
   lives only on the machine that runs the app.

3. **Secrets are scoped by environment.** A dev key and a production key are different secrets,
   issued separately.

4. **Every secret must be rotatable without downtime.** If rotating a key requires a deploy or
   manual coordination, that's a design flaw. Design for rotation from the start.

5. **Secrets are not config.** Non-sensitive environment config (`LOG_LEVEL=debug`,
   `PORT=3000`) can live in committed config files. Credentials, API keys, signing secrets,
   and tokens live in the environment or the secrets manager.

---

## What Is a Secret

**The discriminator: if leaking it lets someone act as you, it's a credential; otherwise it's
config.** (A database connection string is a credential — it contains the password.)

Safe to commit (non-sensitive config):
- `PORT`, `LOG_LEVEL`, `NODE_ENV`
- Public API base URLs
- Feature flag names (not values, if values encode sensitive logic)
- Timeout and retry constants

---

## `.env` File Hygiene

```bash
# .gitignore — verified present on every project
.env
.env.local
.env.*.local
.env.production

# Safe to commit — template only, no real values
.env.example
```

`.env.example` format:
```bash
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
# ^ Replace with your local Postgres connection string

# Stripe
STRIPE_SECRET_KEY=sk_test_...
# ^ Get from https://dashboard.stripe.com/apikeys (use TEST key for local)

# JWT
JWT_SIGNING_SECRET=
# ^ Generate with: openssl rand -base64 32
```

---

## Secret Scanning

Add to CI pipeline — block merges that introduce secrets:

```yaml
# GitHub Actions — using Gitleaks
- name: Scan for secrets
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Also run locally before committing:
```bash
# Install once
brew install gitleaks

# Scan staged changes
gitleaks protect --staged
```

---

## Secret Rotation Pattern

Design every secret-consuming integration for zero-downtime rotation:

```ts
// Wrong — single secret, rotation requires downtime
const token = jwt.verify(incoming, process.env.JWT_SECRET);

// Right — support multiple valid secrets during rotation window
const secrets = [
  process.env.JWT_SECRET_CURRENT,
  process.env.JWT_SECRET_PREVIOUS, // kept for rotation overlap window
].filter(Boolean);

let verified = null;
for (const secret of secrets) {
  try { verified = jwt.verify(incoming, secret); break; }
  catch {}
}
if (!verified) throw new UnauthorizedError();
```

Rotation procedure:
1. Generate new secret
2. Deploy with both `CURRENT` (new) and `PREVIOUS` (old) in env
3. New tokens issued with `CURRENT`; old tokens still verified via `PREVIOUS`
4. After overlap window (e.g. token TTL), remove `PREVIOUS`

---

## Environment Variable Audit Checklist

- [ ] `.env` in `.gitignore` — verified, not just assumed
- [ ] `.env.example` present and up to date with all required vars
- [ ] Source code, comments, and test fixtures carry placeholder values only
- [ ] Dev and CI run against environment-scoped non-production credentials
- [ ] Secret scanning in CI pipeline
- [ ] All secrets documented with: what it is, where to get it, rotation procedure
- [ ] Every `console.log` / `logger.*` call near an env var read audited to confirm it emits the
      variable name, not its value
- [ ] CI secrets held in the platform's secret store (GitHub Actions secrets, etc.) and
      referenced by name in workflow files
- [ ] Database connection string uses a least-privilege DB user (not superuser)
- [ ] Rotation procedure defined and tested for every critical secret — critical means every
      secret that grants write access or costs money

---

If secrets already flow only through the environment or a secrets manager and rotation is
designed in, say so clearly — don't manufacture findings.
