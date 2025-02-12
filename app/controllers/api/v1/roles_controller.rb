class Api::V1::RolesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :auth_from_token
  before_action :set_role, only: %i[show update destroy get_users role_sync]

  # GET /api/v1/roles/:id/sync
  def role_sync
    Rails.logger.debug "Role Sync: Received request with params: #{params.inspect}"

    begin
      AccessProvisionService.run(@role)
      render json: { success: true }, status: :ok
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Role Sync: Validation error: #{e.record.errors.full_messages.join(', ')}"
      render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error "Role Sync: Unexpected error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'An unexpected error occurred. Please try again.' }, status: :internal_server_error
    end
  end

  # GET /api/v1/roles/:id/accesses
  def get_users
    @accesses = Access.where(role_id: @role.id, approved: true)
    render json: @accesses, only: [:user_id, :approved]
  end

  # GET /api/v1/roles/:id
  def show
    render json: @role
  end

  # POST /api/v1/roles
  def create
    role = Role.new(role_attributes)

    if role.save
      Rails.logger.info("Role created: #{role.inspect}")
      render json: role, status: :created
    else
      Rails.logger.error("Role creation failed: #{role.errors.full_messages.join(', ')}")
      render json: { errors: role.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/roles/:id
  def update
    if @role.update(role_attributes)
      Rails.logger.info("Role updated: #{@role.inspect}")
      render json: @role, status: :ok
    else
      Rails.logger.error("Role update failed: #{@role.errors.full_messages.join(', ')}")
      render json: { errors: @role.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/roles/:id
  def destroy
    if @role.destroy
      render json: { message: "Role deleted successfully" }, status: :ok
    else
      render json: { errors: @role.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def role_attributes
    params.permit(
      :name, 
      :system_id, 
      :term, 
      :approval_workflow_id, 
      :autoapproval_workflow_id, 
      :provision_workflow_id, 
      :is_active, 
      :autodenial_workflow_id,
      approval_workflow_properties: { list1: [] },
      provision_workflow_properties: [
        { list1: [] },
        :preserve_members
        ],
      autoapproval_workflow_properties: {},
      autodenial_workflow_properties: {}
    )
  end
end
