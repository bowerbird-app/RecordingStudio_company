# frozen_string_literal: true

require_relative "errors"

module RecordingStudioCompany
  module Api
    module LogoActions
      module_function

      def register!(api)
        register_set_logo(api)
        register_remove_logo(api)
      end

      def register_set_logo(api)
        register_action(api, :set_logo, SetLogo, signed_blob_contract, "Set the company logo")
      end

      def register_remove_logo(api)
        register_action(api, :remove_logo, RemoveLogo, nil, "Remove the company logo")
      end

      def register_action(api, name, handler, input_contract, summary)
        return if ::RecordingStudioApi.capability_action(name, api:)

        ::RecordingStudioApi.register_capability_action(name, **action_options(api, handler, input_contract, summary))
      end

      def action_options(api, handler, input_contract, summary)
        {
          capability: :attachable, version: "1.0.0", http_verb: :post, required_role: :edit,
          handler:, input_contract:, openapi: { summary: }, api:
        }
      end

      def signed_blob_contract
        {
          reject_unknown: false,
          fields: { signed_blob_id: { type: :string, required: true, allow_blank: false } }
        }
      end

      class SetLogo
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :edit)
            RecordingStudioCompany.set_logo(
              context.recording,
              signed_blob_id: context.params[:signed_blob_id],
              actor: context.actor
            )
          end
        end
      end

      class RemoveLogo
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :edit)
            RecordingStudioCompany.remove_logo(context.recording, actor: context.actor)
          end
        end
      end
    end
  end
end
