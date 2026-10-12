# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.5.0`)
- Accessible dummy tag `v0.15.0` (`~> 0.15` in the gemspec)
- Attachable dummy tag `v0.13.0`, Trashable `v0.6.0`, Root Switchable `v0.8.0`
- FlatPack dummy tag `v0.1.213`
- Public RubyGems and GitHub access for dependency installation

Accessible `0.14.0` added access-constraint and access-rule tables. Hosts (and the
dummy app) that jump from an older Accessible pin should run
`bin/rails generate recording_studio_accessible:migrations` then `bin/rails db:migrate`.
Accessible `0.15.0` itself is translation-only and adds no migration.

## Verification

Install both bundles and run the complete gem and dummy app test path:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.
