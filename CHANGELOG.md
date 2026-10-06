# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_company/releases/tag/v0.1.0
