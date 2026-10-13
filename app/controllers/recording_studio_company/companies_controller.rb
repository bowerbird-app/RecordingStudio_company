# frozen_string_literal: true

require "securerandom"

module RecordingStudioCompany
  # rubocop:disable-next Metrics/ClassLength
  class CompaniesController < ApplicationController
    before_action :set_parent, only: %i[index new create]
    before_action :set_company, except: %i[index new create]

    def index
      @allowance = RecordingStudioCompany.allowance(@parent)
      if @allowance == :many
        @trashed_companies, @companies =
          RecordingStudioCompany.companies(@parent, include_trashed: true).partition(&:trashed_at)
      else
        @company = RecordingStudioCompany.company(@parent, include_trashed: true)
      end
    rescue CompanyIntegrityError => e
      @integrity_error = e
    end

    def new
      return redirect_to(recording_companies_path(@parent), alert: flash_cant_add) unless company_can?(:create, @parent)

      @record = Company.new
      @idempotency_key = SecureRandom.uuid
    end

    def create
      company = RecordingStudioCompany.create(
        @parent, actor: current_company_actor, idempotency_key: string_param(:idempotency_key), **company_params
      )
      redirect_to company_path(company), notice: flash_was_added(company), status: :see_other
    rescue Invalid => e
      @record = e.record
      @idempotency_key = string_param(:idempotency_key) || SecureRandom.uuid
      render :new, status: :unprocessable_content
    rescue CompanyAlreadyExists, CompanyIntegrityError => e
      redirect_to recording_companies_path(@parent), alert: Copy.user_message(e.message), status: :see_other
    end

    def show; end

    def edit
      raise Trashed.new(company: @company) if @company.trashed_at

      unless company_can?(:update, @company)
        alert = flash_cant_edit(@company)
        return redirect_to(company_path(@company), alert:)
      end

      @record = @company.recordable
    end

    def update
      company = RecordingStudioCompany.update(@company, actor: current_company_actor, **company_params)
      redirect_to company_path(company), notice: flash_was_saved(company), status: :see_other
    rescue Invalid => e
      @record = e.record
      render :edit, status: :unprocessable_content
    end

    def destroy
      unless @company.trashed_at
        authorize_company!(:trash, @company)
        @company.recording_studio_trashable_trash!(actor: current_company_actor)
      end
      redirect_to recording_companies_path(@company.parent_recording_id),
                  notice: flash_in_trash(@company), status: :see_other
    end

    def restore
      if @company.trashed_at
        authorize_company!(:restore, @company)
        @company.recording_studio_trashable_restore!(actor: current_company_actor)
      end
      redirect_to company_path(@company), notice: flash_was_restored(@company), status: :see_other
    end

    def set_logo
      signed_blob_id = string_param(:logo, :signed_blob_id)
      unless signed_blob_id
        return redirect_to(edit_company_path(@company), alert: flash_choose_image, status: :see_other)
      end

      RecordingStudioCompany.set_logo(@company, signed_blob_id:, actor: current_company_actor)
      redirect_to edit_company_path(@company), notice: flash_logo_updated, status: :see_other
    rescue LogoRejected => e
      redirect_to edit_company_path(@company), alert: Copy.user_message(e.message), status: :see_other
    end

    def remove_logo
      RecordingStudioCompany.remove_logo(@company, actor: current_company_actor)
      redirect_to edit_company_path(@company), notice: flash_logo_removed, status: :see_other
    rescue LogoRejected => e
      redirect_to edit_company_path(@company), alert: Copy.user_message(e.message), status: :see_other
    end

    private

    def set_parent
      @parent = RecordingStudio::Recording.unscoped.find_by(id: params[:recording_id])
      return if @parent && @parent.trashed_at.nil? && RecordingStudioCompany.allowance(@parent) &&
                company_can?(:view, @parent)

      raise NotFound, "No company parent #{params[:recording_id].inspect}"
    end

    def set_company
      @company = RecordingStudioCompany.find(params[:id], include_trashed: true)
      raise NotFound, "No company #{params[:id].inspect}" unless company_can?(:view, @company)
    end

    def company_params
      params.expect(company: Company::FIELDS).to_h.symbolize_keys
    end

    def flash_cant_add
      Copy.t("flashes.cant_add", default: "A company can't be added here.")
    end

    def flash_was_added(company)
      name = company.recordable.name
      Copy.t("flashes.was_added", name:, default: "#{name} was added.")
    end

    def flash_was_saved(company)
      name = company.recordable.name
      Copy.t("flashes.was_saved", name:, default: "#{name} was saved.")
    end

    def flash_in_trash(company)
      name = company.recordable.name
      Copy.t("flashes.in_trash", name:, default: "#{name} is in the trash.")
    end

    def flash_was_restored(company)
      name = company.recordable.name
      Copy.t("flashes.was_restored", name:, default: "#{name} was restored.")
    end

    def flash_cant_edit(company)
      name = company.recordable.name
      Copy.t("flashes.cant_edit", name:, default: "You can't edit #{name}.")
    end

    def flash_choose_image
      Copy.t("flashes.choose_image", default: "Choose an image to upload.")
    end

    def flash_logo_updated
      Copy.t("flashes.logo_updated", default: "The logo was updated.")
    end

    def flash_logo_removed
      Copy.t("flashes.logo_removed", default: "The logo was removed.")
    end
  end
end
