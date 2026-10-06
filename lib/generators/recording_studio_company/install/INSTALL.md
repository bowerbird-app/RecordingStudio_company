===============================================================================

RecordingStudioCompany has been installed successfully!

The engine has been mounted at /recording_studio_company in your application.

Before the company pages work:
1. Install Attachable with 'bin/rails generate recording_studio_attachable:install'
2. Install the Active Storage, Trashable, Attachable, Accessible, and company migrations, then run 'bin/rails db:migrate'
3. Turn on companies for a parent type with 'include RecordingStudio::Capabilities::Companies.to(allow: :one)' or 'allow: :many'

If you use Tailwind CSS:
1. Run 'bin/rails tailwindcss:build' to rebuild your CSS with RecordingStudioCompany styles

To use the engine:
1. Start your Rails server
2. Visit http://localhost:3000/recording_studio_company/recordings/PARENT_RECORDING_ID/companies

===============================================================================
