RecordingStudioCompany install complete.

The engine is mounted at the configured mount path, /recording_studio_company by default.

Next steps:

1. Install Attachable with `bin/rails generate recording_studio_attachable:install`. It mounts Attachable for logo previews, pins its Stimulus controllers and @rails/activestorage, and starts Active Storage.
2. Install the migrations for Active Storage, Trashable, Attachable, Accessible, and companies:
   bin/rails active_storage:install
   bin/rails generate recording_studio_trashable:migrations
   bin/rails generate recording_studio_attachable:migrations
   bin/rails generate recording_studio_accessible:migrations
   bin/rails generate recording_studio_company:migrations
3. Apply the migrations with `bin/rails db:migrate`.
4. Add "RecordingStudioCompany::Company" and "RecordingStudioAttachable::Attachment" to config.recordable_types in config/initializers/recording_studio.rb.
5. Turn on companies for each parent type with `include RecordingStudio::Capabilities::Companies.to(allow: :one)` or `allow: :many`.
6. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.
7. The company pages inherit your ApplicationController. Adjust auth, layout, and current actor integration to match your host app.
8. Link to a parent's companies with `recording_studio_company.recording_companies_path(parent_recording)`.
9. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
