# frozen_string_literal: true

module API
  module V2
    class OrganizationsController < BaseController

      before_action :check_read_permission!, only: [:index, :show]
      before_action :check_write_permission!, only: [:create, :update, :destroy]

      # GET /api/v2/organizations
      def index
        organizations = if @current_user&.admin? || @current_api_token&.has_permission?("*")
                          Organization.present.order(:name)
                        elsif @current_user
                          @current_user.organizations_scope.order(:name)
                        elsif @current_organization
                          [@current_organization]
                        else
                          Organization.none
                        end

        result = paginate(organizations)
        render_paginated(
          OrganizationSerializer.serialize_collection(result[:records]),
          result,
        )
      end

      # GET /api/v2/organizations/:permalink
      def show
        org = find_organization
        render_success OrganizationSerializer.serialize(org, include: params[:include]&.split(",")&.map(&:to_sym))
      end

      # POST /api/v2/organizations
      def create
        org = Organization.new(organization_params)
        org.owner = @current_user || User.first

        if org.save
          render_created OrganizationSerializer.serialize(org)
        else
          render_validation_error(org)
        end
      end

      # PATCH /api/v2/organizations/:permalink
      def update
        org = find_organization

        if org.update(organization_params)
          render_success OrganizationSerializer.serialize(org)
        else
          render_validation_error(org)
        end
      end

      # DELETE /api/v2/organizations/:permalink
      def destroy
        org = find_organization
        org.soft_destroy
        render_destroyed
      end

      # GET /api/v2/organizations/:permalink/domains
      # Returns ONLY domains owned directly by the organization (owner_type: 'Organization')
      def domains
        org = find_organization
        result = paginate(org.domains.order(:name))
        render_paginated(
          DomainSerializer.serialize_collection(result[:records]),
          result,
        )
      end

      private

      def find_organization
        scope = if @current_user&.admin? || @current_api_token&.has_permission?("*")
                  Organization.present
                elsif @current_user
                  @current_user.organizations_scope
                elsif @current_organization
                  Organization.present.where(id: @current_organization.id)
                else
                  Organization.none
                end

        org = scope.find_by_permalink!(params[:permalink])
        org
      end

      def organization_params
        params.permit(:name, :time_zone)
      end

      def check_read_permission!
        require_any_permission!("organizations.read", "servers.read")
      end

      def check_write_permission!
        require_permission!("organizations.write")
      end

    end
  end
end
