# frozen_string_literal: true

require "securerandom"

module RecordingStudioCompany
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
      unless company_can?(:create, @parent)
        return redirect_to(recording_companies_path(@parent), alert: "A company can't be added here.")
      end

      @record = Company.new
      @idempotency_key = SecureRandom.uuid
    end

    def create
      company = RecordingStudioCompany.create(
        @parent, actor: current_company_actor, idempotency_key: string_param(:idempotency_key), **company_params
      )
      redirect_to company_path(company), notice: "#{company.recordable.name} was added.", status: :see_other
    rescue Invalid => e
      @record = e.record
      @idempotency_key = string_param(:idempotency_key) || SecureRandom.uuid
      render :new, status: :unprocessable_content
    rescue CompanyAlreadyExists, CompanyIntegrityError => e
      redirect_to recording_companies_path(@parent), alert: e.message, status: :see_other
    end

    def show; end

    def edit
      raise Trashed.new(company: @company) if @company.trashed_at
      unless company_can?(:update, @company)
        return redirect_to(company_path(@company), alert: "You can't edit #{@company.recordable.name}.")
      end

      @record = @company.recordable
    end

    def update
      company = RecordingStudioCompany.update(@company, actor: current_company_actor, **company_params)
      redirect_to company_path(company), notice: "#{company.recordable.name} was saved.", status: :see_other
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
                  notice: "#{@company.recordable.name} is in the trash.", status: :see_other
    end

    def restore
      if @company.trashed_at
        authorize_company!(:restore, @company)
        @company.recording_studio_trashable_restore!(actor: current_company_actor)
      end
      redirect_to company_path(@company), notice: "#{@company.recordable.name} was restored.", status: :see_other
    end

    def set_logo
      signed_blob_id = string_param(:logo, :signed_blob_id)
      unless signed_blob_id
        return redirect_to(edit_company_path(@company), alert: "Choose an image to upload.", status: :see_other)
      end

      RecordingStudioCompany.set_logo(@company, signed_blob_id:, actor: current_company_actor)
      redirect_to edit_company_path(@company), notice: "The logo was updated.", status: :see_other
    rescue LogoRejected => e
      redirect_to edit_company_path(@company), alert: e.message, status: :see_other
    end

    def remove_logo
      RecordingStudioCompany.remove_logo(@company, actor: current_company_actor)
      redirect_to edit_company_path(@company), notice: "The logo was removed.", status: :see_other
    rescue LogoRejected => e
      redirect_to edit_company_path(@company), alert: e.message, status: :see_other
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
  end
end
