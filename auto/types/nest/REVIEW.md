# Code Review Rules — NestJS

## TypeScript
- No usar `any`. Siempre tipar explícitamente.
- Usar `const` en vez de `let` donde sea posible.
- Strict mode habilitado (`tsconfig.json`).

## NestJS
- Todo endpoint público debe tener DTO con `class-validator` y `whitelist: true`.
- No lógica de negocio en Controllers — solo orquestación.
- Usar `@Injectable()` correctamente, sin singletons manuales.
- No `console.log` — usar `Logger` de NestJS o `Pino`.

## Arquitectura
- Respetar capas: Domain → Application → Infrastructure.
- ❌ No importar módulos de infraestructura desde el Domain Layer.
- ❌ No decoradores ORM dentro de Domain Entities.

## Seguridad
- ❌ No hardcodear credenciales o tokens.
- Todos los secretos deben venir de variables de entorno.
- Sanitizar todas las entradas de usuario con DTOs.

## Testing
- Toda feature nueva necesita tests unitarios.
- Mocks para dependencias externas en unit tests.
- Coverage mínimo: 80% en servicios de negocio.
