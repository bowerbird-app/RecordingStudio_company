# RecordingStudioCompany

Companies for Recording Studio apps. A company is a corporate or legal organization, such as Nike, Inc. or Unilever PLC.

`RecordingStudioCompany::Company` is a generic, non-root recordable. It is not tied to Workspace or to any root type. A host app turns companies on for the parent types it chooses, and each parent type allows one company or many. A parent can be a root recording, such as a press centre or an agency, or a recording inside one, such as a project in an agency.

## Company, brand, person, and location

This gem records companies and nothing else.

- A company is a corporate or legal organization, such as Nike, Inc. or Unilever PLC.
- A brand is a name a company sells under, such as Dove. Brands are not in this gem.
- A person is an individual, such as a press contact. People are not in this gem.
- A location is an office or an address. Locations are not in this gem, and a company has no address fields.

## Example

The dummy app records this tree. Each parent holds its own company recordings, so the Nike, Inc. under Nike Newsroom and the Nike, Inc. under Northwind are separate companies.

```text
Nike Newsroom (press centre, allow: :one)
  Nike, Inc.
Northwind (agency, allow: :many)
  Acme Coffee Pty Ltd
  Nike, Inc.
  Unilever
    # Not part of this gem. A future brand gem could list Unilever's brands here.
    #   Dove
    #   Hellmann's
    #   Lipton
  Harbour fit-out (project, allow: :one)
    Acme Engineering Pty Ltd
```

## Install

Add the gem. Recording Studio gems are not published to RubyGems, so resolve the gem and its dependencies from GitHub tags.

```ruby
# Gemfile
gem "recording_studio_company", github: "bowerbird-app/RecordingStudio_company", tag: "v0.2.1"

gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.203"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.2"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.11.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.7.1"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.4.4"
```

Run the install generators and the migrations.

```sh
bin/rails generate recording_studio_company:install     # mounts the engine at /recording_studio_company
bin/rails generate recording_studio_attachable:install  # mounts Attachable, pins its Stimulus controllers, starts Active Storage

bin/rails active_storage:install
bin/rails generate recording_studio_trashable:migrations
bin/rails generate recording_studio_attachable:migrations
bin/rails generate recording_studio_accessible:migrations
bin/rails generate recording_studio_company:migrations  # copies the company migrations
bin/rails db:migrate
```

## Upgrade from 0.1.0

0.2.0 removes legal name, email, and founded date. Pin `v0.2.0`, copy the new migration, and migrate.

```sh
bin/rails generate recording_studio_company:migrations
bin/rails db:migrate
```

The migration drops `legal_name`, `email`, `phone`, and `founded_on` from `recording_studio_companies`. Those values are not kept. Stop passing them to `RecordingStudioCompany.create` and `.update`. Name, description, website, and the logo stay. The edit form asks for the name, then the website, then the description.

The company page stacks the logo, name, description, and website, and puts Edit company at the bottom. Restore stays on the company page. The edit form's button says Save. It stays the default style until a field changes, then it turns primary. Delete sits on that same row, on the right, and moves the company to the trash. That needs Flatpack `v0.1.200` or newer.

## Upgrade from 0.2.0

Pin `v0.2.1`. There is no migration. The edit button says Save, and Delete sits on that row. Hosts that replaced the company edit view keep that view.

List the company and attachment types in the Recording Studio initializer. The engine also registers the company type after your initializers run, but listing it keeps the configuration in one place.

```ruby
# config/initializers/recording_studio.rb
RecordingStudio.configure do |config|
  config.recordable_types = [
    "PressCentre", "Agency", "Project",
    "RecordingStudioCompany::Company",
    "RecordingStudioAttachable::Attachment"
  ]
end
```

The company pages inherit the host's `ApplicationController`, so its authentication and `Current.actor` setup run first. The pages act as `Current.actor` when the host defines it, and as `current_user` otherwise. They render in `recording_studio/default_layout` with FlatPack components.

## Turn on companies for a parent type

Include `RecordingStudio::Capabilities::Companies.to` in each parent recordable type that holds companies. `allow: :one` limits each recording of the type to one company. `allow: :many` sets no limit.

```ruby
class PressCentre < ApplicationRecord
  recording_studio_recordable label: "Press centre", root: true
  RecordingStudio.enable_capability(:accessible, on: self)
  include RecordingStudio::Capabilities::Companies.to(allow: :one)
end

class Agency < ApplicationRecord
  recording_studio_recordable label: "Agency", root: true
  RecordingStudio.enable_capability(:accessible, on: self)
  include RecordingStudio::Capabilities::Companies.to(allow: :many)
end

class Project < ApplicationRecord
  recording_studio_recordable label: "Project", root: false, allowed_parent_types: ["Agency"]
  include RecordingStudio::Capabilities::Companies.to(allow: :one)
end
```

`allow:` is required. Leaving it out, or passing anything other than `:one` or `:many`, raises `RecordingStudioCompany::ConfigurationError` when the class loads. Shared roots cannot hold companies. A type that does not include the capability, such as the dummy app's Workspace, holds no companies, and its company page returns 404.

With `allow: :one`, a trashed company still holds the place until it is purged. The page offers Restore instead of Add, so restoring can never produce a second live company.

## Use companies

### The company recording

A company is a `RecordingStudio::Recording` whose `recordable_type` is `"RecordingStudioCompany::Company"`. Every public method takes and returns these company recordings, and the fields live on `company.recordable`.

Store the recording id, `company.id`, when another record points at a company. The recordable id changes on every edit, because each edit inserts a new snapshot.

```ruby
class PressRelease < ApplicationRecord
  # company_recording_id holds company.id
  def company
    RecordingStudioCompany.find(company_recording_id)
  rescue RecordingStudioCompany::NotFound
    nil
  end
end
```

### Fields

| Field | Notes |
|---|---|
| `name` | Required, up to 200 characters |
| `description` | Up to 5,000 characters |
| `website_url` | Up to 2,048 characters. `website_href` returns a safe http or https link, or nil |
| Logo | One image of up to 10 MB, set with `set_logo` |

Surrounding whitespace is stripped, and blank values are stored as nil. Website is not format-checked. `RecordingStudioCompany::Company::FIELDS` lists the fields, and `RecordingStudioCompany::Company::LIMITS` holds the lengths that the validations and the form's `maxlength` attributes read.

### Create

```ruby
nike = RecordingStudioCompany.create(
  press_centre,
  actor: Current.actor,
  idempotency_key: "seed:nike-inc",
  name: "Nike, Inc.",
  website_url: "https://about.nike.com"
)

RecordingStudioCompany.create(press_centre, actor: Current.actor, name: "Converse")
# raises RecordingStudioCompany::CompanyAlreadyExists, and error.company == nike
```

Creating needs Accessible `:edit` on the parent, and the host's `config.authorize_write` still runs inside `RecordingStudio.record!`. Within one parent, an idempotency key that already created a company returns that company. `create` raises these errors:

- `ParentNotAllowed` when the parent's type does not turn on companies
- `NotAuthorized` without `:edit` on the parent, or when the host denies the write
- `Invalid` when a field is invalid, with the unsaved company in `error.record`
- `CompanyAlreadyExists` when a one-company parent already holds a company, live or trashed
- `CompanyIntegrityError` when a one-company parent already holds more than one company

The one-company limit is a validation on `RecordingStudio::Recording`. It runs inside `RecordingStudio.record!` after the parent row is locked, so every write path enforces it, not only `create`.

### Read

```ruby
RecordingStudioCompany.allowance(agency)                        # :one, :many, or nil
RecordingStudioCompany.companies(agency)                        # live companies by name, then creation
RecordingStudioCompany.companies(agency, include_trashed: true)
RecordingStudioCompany.company(press_centre)                    # the company or nil, on one-company parents
RecordingStudioCompany.company(press_centre, include_trashed: true)
RecordingStudioCompany.find(id)                                 # raises NotFound
RecordingStudioCompany.find(id, include_trashed: true)
```

Reads do not authorize. `company` raises `ManyCompaniesAllowed` on a many-company parent. It raises `CompanyIntegrityError` when a one-company parent holds more than one company recording, live or trashed, and never picks one of them. The extra companies have to be moved or purged.

### Edit

```ruby
RecordingStudioCompany.update(nike, actor: Current.actor, description: "Athletic footwear and apparel.")
```

`update` revises the given fields through Recording Studio's `revise`. The recording id stays the same, and earlier snapshots stay in `company.recordables`. When nothing changes, it records nothing. It needs `:edit` on the company and raises `NotAuthorized`, `Invalid`, or `Trashed`.

### Logo

```ruby
blob = ActiveStorage::Blob.create_and_upload!(io: File.open("nike.png"), filename: "nike.png")
RecordingStudioCompany.set_logo(nike, signed_blob_id: blob.signed_id, actor: Current.actor)
RecordingStudioCompany.logo(nike) # the live logo attachment recording, or nil
RecordingStudioCompany.remove_logo(nike, actor: Current.actor)
```

A company has one logo, an image of up to 10 MB stored as an Attachable attachment named "logo". `set_logo` replaces the file of the existing logo instead of adding a second attachment, and `remove_logo` moves the logo to the trash. The next `set_logo` restores the same logo recording with the new file. A file that Attachable rejects raises `LogoRejected`.

Logo images are served by Attachable's preview route, so Attachable has to be mounted and the viewer needs `:view` access.

### Trash and restore

Trash and restore are Trashable's own methods.

```ruby
nike.recording_studio_trashable_trash!(actor: Current.actor)
nike.recording_studio_trashable_restore!(actor: Current.actor)
```

Trashing a company also trashes its logo, and restoring the company restores the logo. A trashed company cannot be edited until it is restored.

### Permissions

`RecordingStudioCompany.can?(action, recording, actor:)` says whether an action is available now. The company pages use it to show or hide their buttons.

- `:view` needs Accessible `:view` on the recording
- `:create` needs a parent type that turns on companies, a free place on a one-company parent, and `:edit` on the parent
- `:update` needs a live company and `:edit`
- `:trash` needs a live company and Trashable's trash authorization
- `:restore` needs a trashed company and Trashable's restore authorization

### Display a company on any page

```erb
<%= recording_studio_company_logo(company, size: :sm) %>
<%= recording_studio_company_card(company) %>
```

`recording_studio_company_logo` renders a FlatPack avatar with the live logo, or the company's initials when it has none. It is rounded unless you pass `shape: :circle`. `recording_studio_company_card` renders a read-only profile with the logo, name, description, and website, and leaves blank fields out. The card links nothing in the company pages, so other gems can render it on their own pages.

## Company pages

The engine serves these pages under its mount path. Link to a parent's page with `recording_studio_company.recording_companies_path(parent)`.

| Verb | Path | Page or action |
|---|---|---|
| GET | `/recordings/:recording_id/companies` | The parent's company or companies |
| GET | `/recordings/:recording_id/companies/new` | Add a company |
| POST | `/recordings/:recording_id/companies` | Create |
| GET | `/companies/:id` | View a company |
| GET | `/companies/:id/edit` | Edit a company and its logo |
| PATCH | `/companies/:id` | Save |
| DELETE | `/companies/:id` | Move to the trash |
| POST | `/companies/:id/restore` | Restore |
| PATCH | `/companies/:id/logo` | Set the logo from `logo[signed_blob_id]` |
| DELETE | `/companies/:id/logo` | Remove the logo |

The index is titled "Companies and organisations" and has no parent subtitle. + Company sits under the title when another company can be added. Live companies are names in a list inside a card, and each name opens that company. On a wide screen the list sits in the first column of a two-column grid. On a one-company parent, a trashed company offers Restore and no + Company. When that parent holds more than one company, the page says so and offers no + Company. A trash section with Restore follows a many-company list.

A company page stacks a circular logo, the name in a large heading, the description, and the website. Blank description and website are left out. Edit company sits at the bottom. The page has no delete button. Restore stays there when the company is in the trash.

The edit page shows the logo beside Upload logo, or Change logo and Remove logo when a logo is already set, then the company fields. The logo has no card and no heading of its own. Save and Cancel sit under the fields, and Delete sits on the right of that row.

An unknown parent, a parent whose type holds no companies, and a parent or company the actor cannot view all return 404. A denied write returns 403.

## Capabilities

The company type turns on these capabilities:

- Trashable, for trash and restore
- Attachable, for the logo, limited to one image of up to 10 MB, with `:edit` needed to upload, replace, remove, or restore it

The engine also turns on Trashable for `RecordingStudioAttachable::Attachment` when the host has not, so removing a logo moves it to the trash.

These capabilities are left out on purpose:

- Accessible is not turned on for companies. Access comes from grants on the parent recording or its ancestors, and creating is authorized against the parent.
- Duplicatable is left out because a company is an identity, and a copy would bypass the one-company limit.
- Orderable is left out because company lists sort by name, then by creation.

## Dummy app

`test/dummy` is the host app used to develop and test the gem. It keeps the template's Workspace, Folder, and Page recordables and adds the press centre, agency, and project from the example tree. Workspace does not turn on companies.

```bash
cd test/dummy
bin/rails db:setup   # creates, migrates, and seeds the database
bin/dev
```

Sign in at `/users/sign_in` with `admin@admin.com` and `Password`. The home page links to each parent's company page. `bin/rails db:seed` can run again without adding users, recordings, or companies.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio development master key. Set `RAILS_MASTER_KEY`, or put the key in `test/dummy/config/master.key`, which is gitignored.

## Tests

```bash
bundle exec rake test       # gem tests that need no database
bundle exec rake test:all   # gem tests, dummy app tests, and the database-backed company tests
bundle exec rubocop
```

`rake test:all` needs PostgreSQL. It prepares the test database with `RAILS_ENV=test` and does not load `db/seeds.rb` (the test config sets `seeds: false`). It runs each database-backed file in `test/companies` and `test/controllers` under the dummy app's bundle. Demo companies are created inside the examples that need them.

## Documentation

`docs/gem_template/` keeps the Recording Studio gem template's documentation as background on the engine conventions. This README and the dummy app describe the company gem.
