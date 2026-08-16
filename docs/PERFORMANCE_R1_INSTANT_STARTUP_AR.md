# Optimum 6.9.1 — Performance R1: Instant Startup & Lazy Modules

## Baseline
Certified production parent:
`4013f381d5423ddee3f47e40229651e3bfe9d84b`

## Why this phase exists
The certified client shell statically imported Engineering, Work OS, Operations Center,
Project Control and Site Supervisor. Those five files represent more than 700 KiB of raw
JavaScript before accounting for the core shell itself.

The previous boot also loaded the full Work OS and Engineering data whenever the current
role merely had permission to use those areas.

## R1 design
- Keep API, config, i18n, icons, Access Engine and Organization OS in the critical core.
- Dynamically import Engineering, Work OS, Operations Center, Project Control and Site Supervisor.
- Keep the Dashboard task focus queue through a lightweight `work_task_query` +
  `work_delivery_snapshot` path that does not import Work OS.
- Management Home loads only Operations + Project Control because those summaries are part
  of the approved Home experience.
- Site Supervisor Home loads only the field workspace.
- Engineering and Work OS load only when their routes are requested.
- Navigation hover/focus prefetches module code without issuing module data queries.
- Deep links use an explicit loading workspace instead of rendering an unrelated fallback page.
- Route activations are epoch-guarded to avoid stale async navigation races.
- Full refresh/company switch invalidates lazy module data caches.
- No permission, role, Supabase schema, RLS or business workflow change.

## Regression gate
`npm run test:performance-r1`

The gate:
- blocks static imports for the five deferred modules,
- verifies dynamic imports,
- recursively measures the real static local JS import graph,
- requires the initial graph to remain below 820 KiB,
- requires more than 700 KiB to remain outside the startup graph,
- blocks a return to unconditional Engineering boot,
- verifies lazy-safe Engineering event delegation,
- is included in `npm run test:release`.

## Production rule
This branch must pass Performance R1 + Full Release + protected Vercel Preview certification
before any production promotion.
