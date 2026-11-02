# frozen_string_literal: true

module RecordingStudioCompany
  module Access
    # Whether actor may take an action right now.
    #   :view    Accessible :view on the recording (a parent or a company)
    #   :create  the parent's type enables companies, the company place is free, and Accessible :edit
    #   :update  a live company and Accessible :edit
    #   :trash   a live company and Trashable's :trash authorization
    #   :restore a trashed company and Trashable's :restore authorization
    def can?(action, recording, actor:)
      case action
      when :view then can_view?(recording, actor)
      when :create then can_create?(recording, actor)
      when :update then can_update?(recording, actor)
      when :trash then can_trash?(recording, actor)
      when :restore then can_restore?(recording, actor)
      else
        raise ArgumentError, "Unknown action #{action.inspect}; expected one of #{ACTIONS.join(', ')}"
      end
    end

    private

    def can_view?(recording, actor) = allowed?(recording, :view, actor)

    def can_create?(parent, actor)
      allowance(parent).present? && Slots.vacant?(parent) && allowed?(parent, :edit, actor)
    end

    def can_update?(company, actor) = live_company?(company) && allowed?(company, :edit, actor)

    def can_trash?(company, actor)
      live_company?(company) && RecordingStudioTrashable.authorized?(action: :trash, actor:, recording: company)
    end

    def can_restore?(company, actor)
      company_recording?(company) && company.trashed_at.present? &&
        RecordingStudioTrashable.authorized?(action: :restore, actor:, recording: company)
    end
  end
  private_constant :Access
end
