# Project Guidelines

## Architecture

- This repository is the RecordingStudioCompany addon: company profiles under host-chosen parent recordings.
- Keep the engine namespace `RecordingStudioCompany`.
- Prefer the top-level README and the dummy app over leftover template docs.
- Keep changes small and scoped.

## UI conventions

- FlatPack is the UI system. Compose `render FlatPack::...` components.
- Company screens use core's default layout through `recording_studio_layout`.
- Do not hard-code `layout "recording_studio/default_layout"` or include `UsesDefaultLayout`.

## Testing

- Gem suite: `bundle exec rake test`
- Dummy and database-backed company tests: `bundle exec rake test:all`
- Add focused tests for layout configuration, engine wiring, and company writes.
