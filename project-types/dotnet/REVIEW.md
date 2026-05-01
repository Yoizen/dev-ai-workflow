# .NET Code Review Checklist

## C#
- [ ] Nullable reference types respected
- [ ] `record` used for DTOs
- [ ] No exceptions for flow control
- [ ] Async/await used correctly

## Architecture
- [ ] Clean Architecture layers respected
- [ ] DI via constructor (not service locator)

## Standards
- [ ] Methods ≤ 60 lines
- [ ] Files ≤ 400 lines
- [ ] Tests for business logic
