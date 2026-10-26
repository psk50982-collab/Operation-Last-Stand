# Operation Last Stand

An offline, single-player Android FPS with survival-wave combat, built from the Kenney Godot 4.6 Starter Kit.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 5000)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- Required env: `DATABASE_URL` — Postgres connection string

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5
- DB: PostgreSQL + Drizzle ORM
- Validation: Zod (`zod/v4`), `drizzle-zod`
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)

## Where things live

- `game/` — Godot project, gameplay scripts, scenes, and licensed starter assets.

## Architecture decisions

- Extend the existing Godot starter and preserve its licensed assets/notices; avoid replacing working systems without a specific need.
- Keep the game offline and single-player; no backend, login, or monetization is required.

## Product

An Android-first, offline FPS intended to grow through explicitly approved development stages: core combat, wave survival, touch controls, visual polish, and APK delivery.

## User preferences

- Budget is ₹0. Avoid paid services, plugins, assets, and unnecessary large downloads.
- Conserve Replit AI credits. Work only on the stage explicitly approved, report only tests actually run, then stop for approval before the next stage.
- Do not make the game source public without explicit permission. Public GitHub Actions runners are the identified free cloud-build route; private-repository costs depend on the account's allowance.

## Gotchas

_Populate as you build — sharp edges, "always run X before Y" rules._

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
