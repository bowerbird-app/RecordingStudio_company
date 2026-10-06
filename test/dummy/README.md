# Dummy app

This Rails app is the host used to develop and test RecordingStudioCompany. It runs the company pages, the seeds, and the database-backed tests.

## What it covers

- Devise sign-in with a seeded admin user, and `Current.actor` for Recording Studio events
- A press centre that holds one company, an agency that holds many, and a project inside the agency that holds one
- The company engine at `/recording_studio_company`, and Attachable at `/recording_studio_attachable` for logo previews
- Workspace, Folder, and Page recordables from the template, with companies left off Workspace
- The Recording Studio default layout, FlatPack, and Tailwind source scanning
- Dummy-only `/docs/*` pages

## Quick start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands from the dummy app directory, not the repository root. Then sign in with these credentials:

- Email: `admin@admin.com`
- Password: `Password`

## Seeds

`db/seeds.rb` creates the admin user, the template's workspaces, and these company parents:

- Press centre "Nike Newsroom" (one company) with Nike, Inc. and a generated placeholder logo
- Agency "Northwind" (many companies) with Nike, Inc., Unilever, and Acme Coffee Pty Ltd
- Project "Harbour fit-out" inside Northwind (one company) with Acme Engineering Pty Ltd

The admin user owns the press centre and the agency through Accessible. Running `bin/rails db:seed` again adds no users, recordings, or companies, because each company is created with a fixed idempotency key.

Those rows belong to the development database. The test database sets `seeds: false`, and `rake test:all` prepares that database with `RAILS_ENV=test`. Examples that read every recording, including the home page before the demo exists and the recordings tree, start from an empty database.

## Useful routes

- `/` shows the three company parents and links to their company pages
- `/recording_studio_company/recordings/:recording_id/companies` lists the companies of a parent recording
- `/recording_studio_company/companies/:id` shows one company
- `/recording_studio` redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` is the Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, and `/docs/methods` are dummy-only reference pages
- `/up` is the Rails health check

## Notes

Authenticated pages use Recording Studio's shared default layout. Devise sign-in keeps `layouts/application`.

Keep the home page in `app/views/home/index.html.erb` a small demo of the company pages. Longer explanations belong on the dummy docs pages.
