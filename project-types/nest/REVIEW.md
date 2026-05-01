# NestJS Code Review Checklist

## TypeScript
- [ ] Strict mode (`noImplicitAny`, strict null checks)
- [ ] No `any` type used
- [ ] Proper DTOs with class-validator decorators
- [ ] `whitelist: true` on ValidationPipe

## Architecture
- [ ] Clean Architecture layers respected
- [ ] No infrastructure imports in Domain
- [ ] No direct SQL/ORM queries in Application layer

## NestJS
- [ ] Controllers are thin (delegate to services)
- [ ] Use `ConfigService` for env vars
- [ ] Pino logger used (no `console.log`)

## Standards
- [ ] Services ≤ 80 lines, files ≤ 500 lines
- [ ] Soft deletes on critical entities
- [ ] Pagination on list endpoints
