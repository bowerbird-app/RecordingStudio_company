# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.3.0
[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.2.2
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.1.0
