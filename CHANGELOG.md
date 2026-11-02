# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.7] - 2026-11-02

### Changed

- Company card names use FlatPack `SectionTitle` (`size: :md`, `spacing: :none`, `level: :h3`)
- Company card and company page websites use FlatPack `Link` (new tab, `noopener noreferrer`)
- Dummy Sign out uses Button `href:` (FlatPack ≥ 0.1.177)
- Gemspec requires `flat_pack` `>= 0.1.210` (SectionTitle `size`, `spacing`, and `level`)

### Upgrade

Pin `v0.4.7`. There is no migration. Hosts must already be on FlatPack `v0.1.210` or newer. The dummy lock stays on `v0.1.213`. The logo file field is unchanged.

## [0.4.6] - 2026-11-02

### Changed

- Company reads, writes, access checks, and slot occupancy live in separate modules under `lib/recording_studio_company/`
- Configuration `to_h` reports hook counts through `RecordingStudio::Hooks#registered_counts`

### Upgrade

Pin `v0.4.6`. There is no migration. Hosts already on `v0.4.5` keep the same company API.

## [0.4.5] - 2026-11-02

### Changed

- `VERSION` is `0.4.5`, matching a patch after the `v0.4.1`–`v0.4.4` Git tags that only bumped companion gems
- README install tags match the current Gemfiles (`recording_studio_company` `v0.4.5`)
- Gemspec description lists name, description, website, and logo
- Dummy and Codespaces database names use `recording_studio_company_*`
- Security (and CI lint) `setup-ruby` uses `ruby-version: '3.3'` so Ubuntu 26.04 runners can install Ruby
- SimpleCov `coverage/` directories are gitignored and no longer tracked

### Upgrade

Pin `v0.4.5`. There is no migration. Hosts already on `v0.4.0` or a later tag keep the same company API. Point the GitHub tag at `v0.4.5`.

## [0.4.4] - 2026-10-19

### Changed

- Dummy and root Trashable pin is `v0.11.0`

### Upgrade

Pin `v0.4.4`. There is no company migration. The gem `VERSION` file still said `0.4.0` on this tag.

## [0.4.3] - 2026-10-14

### Changed

- Dummy and root Accessible pin is `v0.18.0`

### Upgrade

Pin `v0.4.3`. There is no company migration. The gem `VERSION` file still said `0.4.0` on this tag.

## [0.4.2] - 2026-10-14

### Changed

- Dummy and root Recording Studio pin is `v4.6.0`

### Upgrade

Pin `v0.4.2`. There is no company migration. The gem `VERSION` file still said `0.4.0` on this tag.

## [0.4.1] - 2026-10-13

### Changed

- Dummy and root Accessible pin is `v0.17.0`

### Upgrade

Pin `v0.4.1`. There is no company migration. The gem `VERSION` file still said `0.4.0` on this tag.

## [0.4.0] - 2026-10-13

### Added

- English Rails I18n keys for controller flashes, error-page titles, and known lib message mapping under `recording_studio.company` (`flashes`, `errors`, `messages`)
- `RecordingStudioCompany::Copy` for render-time lookups with English `default:` values

### Changed

- Company controller flashes and error-page titles resolve through `Copy.t` / `Copy.user_message` (English output unchanged)
- Form alert descriptions map known slot messages through `Copy.user_message` at render (English output unchanged)
- README interface-text section covers controller flashes and lib-literal mapping

### Upgrade

Pin `v0.4.0`. There is no migration. English hosts need no change. To override or add another language, set keys under `recording_studio.company` in the host's `config/locales`. Lib return values and raised exception messages stay English literals; controllers map known messages at render. There is no dependency on `recording_studio_internationalization`.

## [0.3.0] - 2026-10-09

### Added

- English Rails I18n keys for static interface copy in the gem's own company screens (`config/locales/en.yml` under `recording_studio.company`)

### Changed

- Company view and display-helper labels (titles, buttons, form labels, empty states, trash and integrity alerts, logo alt text) resolve through `t(...)` / `I18n.t(...)` (English output unchanged)

### Upgrade

Pin `v0.3.0`. There is no migration. English hosts need no change. To override or add another language, set keys under `recording_studio.company` in the host's `config/locales`. There is no dependency on `recording_studio_internationalization`. There was no older top-level `recording_studio_company.*` UI locale namespace to migrate.

## [0.2.2] - 2026-10-09

### Changed

- The edit form's button says Save. It stays the default style until a field changes, then it turns primary. Delete sits on that same row, on the right. The divider under the form is gone.

### Upgrade

Pin `v0.2.2`. There is no migration. Hosts that replaced the company edit view keep that view.

## [0.2.1] - 2026-10-08

### Changed

- The Recording Studio pin is `v4.3.0`.

### Upgrade

Pin `v0.2.1`. There is no company migration.

## [0.2.0] - 2026-10-07

### Removed

- `legal_name`, `email`, `phone`, and `founded_on`. A company keeps name, description, website, and one logo.

### Changed

- Delete sits on the right of the edit page, under a divider, and moves the company to the trash. The company page no longer shows Move to trash. Restore stays on the company page.
- The company page stacks the logo, name, description, and website. Edit company sits at the bottom.
- The edit form's button says Update. It stays the default style until a field changes, then it turns primary.

### Upgrade

Hosts on 0.1.0 pin `v0.2.0`, then copy and run the new migration:

```sh
bin/rails generate recording_studio_company:migrations
bin/rails db:migrate
```

That drops `legal_name`, `email`, `phone`, and `founded_on` from `recording_studio_companies`. The values are not kept. Remove those keys from `RecordingStudioCompany.create` and `.update`, and from any screen that read them. The edit form asks for the name, then the website, then the description. Hosts that replaced the company show view keep that view. The default page stacks the logo, name, description, and website, with Edit company at the bottom.

Pin `flat_pack` at `v0.1.200` or newer. The edit form uses Flatpack's unsaved-changes controller, so Update stays the default style until a field changes, then turns primary. Hosts that replaced the company edit view keep that view. Delete sits on the right.

## [0.1.0] - 2026-10-06

The first release of RecordingStudioCompany. The repository started from the Recording Studio gem template.

### Added

- `RecordingStudioCompany::Company`, a non-root recordable for corporate or legal organizations, with name, legal name, description, website, email, phone, founded date, and one logo.
- `RecordingStudio::Capabilities::Companies.to(allow: :one)` and `.to(allow: :many)`, so a host chooses one company or many for each parent type.
- The one-company limit as a validation on `RecordingStudio::Recording`, enforced inside `RecordingStudio.record!` for every write path. A trashed company keeps its place until it is purged.
- `RecordingStudioCompany.allowance`, `.companies`, `.company`, `.find`, `.create`, `.update`, `.set_logo`, `.remove_logo`, `.logo`, and `.can?`.
- `RecordingStudioCompany::CompanyIntegrityError` when a one-company parent already holds more than one company.
- The `recording_studio_company_logo` and `recording_studio_company_card` view helpers.
- Company pages built with FlatPack on the Recording Studio default layout, to list, add, view, edit, trash, and restore companies and to set or remove the logo.
- The `recording_studio_companies` migration and an install generator that mounts the engine at `/recording_studio_company`.
- A dummy app with a press centre, an agency, and a project, plus seeds that can run more than once.

### Changed

- The company index is titled "Companies and organisations". + Company sits under the title when another company can be added. Companies are names in a card, and each name opens that company. On a wide screen the list sits in the first column of a two-column grid. Names are vertically centered in the row.
- On the edit page the logo sits with Upload logo, Change logo, and Remove logo. It has no card and no Logo heading.

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_company/compare/v0.4.7...HEAD
[0.4.7]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.4.7
[0.4.6]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.4.6
[0.4.5]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.4.5
[0.4.4]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.4.4
[0.4.3]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.4.3
[0.4.2]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.4.2
[0.4.1]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.4.1
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.3.0
[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.2.2
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.1.0
