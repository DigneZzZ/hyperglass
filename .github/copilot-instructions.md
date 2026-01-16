# Hyperglass Copilot Instructions

## Architecture Overview
Hyperglass is a network looking glass application that allows querying network devices (BGP, ping, traceroute) via a web interface. It consists of:
- **Backend**: Python with Litestar (async web framework), Pydantic for data models, Netmiko for SSH connections to devices, Redis for state management.
- **Frontend**: Next.js with TypeScript, Chakra UI for components.
- **Configuration**: YAML/TOML files loaded via `hyperglass.configuration.load`.
- **Plugins**: Extensible system for custom commands in `hyperglass/plugins/`.

Key directories: `hyperglass/` (backend), `hyperglass/ui/` (frontend), `docs/` (documentation).

## Development Workflows
- **Start backend**: `python -m hyperglass.main` (builds UI if needed) or `uvicorn hyperglass.api:app`.
- **Start UI dev server**: `cd hyperglass/ui && pnpm dev` (runs on port 3000).
- **Build UI**: `python -m hyperglass.console build-ui` (exports static files to `hyperglass/static/ui`).
- **Run tests**: `pytest hyperglass` (backend), `cd hyperglass/ui && pnpm test` (frontend with Vitest).
- **Lint/format**: `task check` (runs Ruff on Python, Biome on JS/TS).
- **Full dev setup**: Use `compose.yaml` with Redis for local development.

## Code Conventions
- **Python**: Black (100 char lines), isort (balanced wrapping), Ruff linter. Use async/await everywhere. Models in `hyperglass/models/` use Pydantic v2.
- **JS/TS**: Biome formatter (2-space indent, single quotes, trailing commas). Components in `hyperglass/ui/components/`, hooks in `hooks/`.
- **Config**: Files like `devices.yaml`, `params.yaml` in app path. Use `find_path()` and `load_dsl()` for loading.
- **Execution**: Device queries via `hyperglass.execution.main.execute()`, drivers in `drivers/` (NetmikoConnection or HttpClient).
- **API**: Routes in `hyperglass/api/routes.py`, use Litestar decorators, dependency injection with `Provide()`.

## Examples
- **Add query type**: Extend `Query` model in `hyperglass/models/api/`, add route handler, implement execution logic.
- **New device driver**: Subclass `Connection` in `hyperglass/execution/drivers/`, register in `map_driver()`.
- **UI component**: Use Chakra UI, place in `hyperglass/ui/components/`, export from `index.ts`.

Focus on async patterns, Pydantic validation, and separating backend/frontend concerns.</content>
<parameter name="filePath">/Users/dignezzz/Documents/GitHub/hyperglass/.github/copilot-instructions.md