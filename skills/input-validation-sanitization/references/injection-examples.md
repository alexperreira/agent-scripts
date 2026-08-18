# Injection Prevention Examples

Loaded by `input-validation-sanitization` when a change builds a SQL query, a filesystem path,
or a subprocess invocation out of user input. Each section shows the unsafe form and the safe
form side by side.

---

## SQL Injection

```ts
// ❌ String interpolation — SQL injection
const result = await db.query(
  `SELECT * FROM users WHERE email = '${email}'`
);

// ✅ Parameterized query — always
const result = await db.query(
  'SELECT * FROM users WHERE email = $1', [email]
);

// ✅ ORM with typed inputs (Prisma, Drizzle) — injection-safe by default
const user = await prisma.users.findFirst({ where: { email } });
```

Parameterization covers values, not identifiers. A user-supplied column or table name must be
mapped through an allowlist to a literal identifier in code.

---

## Path Traversal

```ts
import path from 'path';

// ❌ User-controlled filename used directly
const filePath = `./uploads/${req.query.filename}`;
// filename = '../../.env' → reads secrets

// ✅ Resolve and verify path is within allowed directory
const uploadsDir = path.resolve('./uploads');
const requestedPath = path.resolve(uploadsDir, req.query.filename);

if (!requestedPath.startsWith(uploadsDir + path.sep)) {
  throw new ForbiddenError('Path traversal attempt');
}
```

The `+ path.sep` matters: comparing against `uploadsDir` alone also accepts a sibling directory
whose name starts with the same string (`./uploads-backup`).

---

## Command Injection

```ts
import { execFile } from 'child_process';

// ❌ Shell interpolation with user input
exec(`convert ${userInput} output.jpg`);

// ✅ execFile with argument array — no shell interpretation
execFile('convert', [userInput, 'output.jpg'], callback);
```

`execFile` with an argv array is the target form because no shell parses the arguments — quoting
and escaping stop being part of the threat model.
