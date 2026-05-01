# NestJS Engineering Constitution

## Stack
- Node.js LTS, NestJS, TypeScript (strict mode)
- Clean Architecture: Domain / Application / Infrastructure

## Critical Rules
- No `any` — use `unknown`, generics, or DTOs
- No ORM decorators in Domain entities (Infrastructure only)
- DTOs must use `class-validator` with `whitelist: true`
- No `process.env.VAR` directly — use `ConfigService.get()`
- Services ≤ 80 lines, files ≤ 500 lines
- `Pino` for logging (no `console.log`)

## Skills

| Action | Skill |
|--------|-------|
| Type definitions / TS code | `typescript` |
| Lint / format | `biome` |
| Git commit | `git-commit` |
| Create or document a skill | `skill-creator` |

## Folder Structure (feature module)
```
src/modules/users/
├── controllers/
├── services/
├── dto/
├── entities/
└── users.module.ts
```
