# Common High-Risk Upgrade Patterns

Read this when the package being upgraded is an ORM, auth library, validation library, bundler or
transpiler, or CSS-in-JS/styling library. These warrant extra caution regardless of blast radius.

| Pattern | Why it's risky | Mitigation |
|---|---|---|
| ORM major bump (Prisma, SQLAlchemy) | Migration API, type generation, query builder changes | Test all DB queries; check generated client output |
| Auth library bump (next-auth, JWT) | Session format, token structure, callback signatures | Test all auth flows; check token compatibility with existing sessions |
| Validation library bump (Zod, Pydantic) | Schema API redesign, error shape changes | Audit all schemas; test error handling paths |
| Bundler / transpiler bump (webpack, vite, babel) | Config format, plugin API, output differences | Review config file; check all environment builds |
| CSS-in-JS / styling library bump | Class name generation, API changes | Visual regression testing recommended |
