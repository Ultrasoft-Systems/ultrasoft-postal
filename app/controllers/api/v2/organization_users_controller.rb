# frozen_string_literal: true

module API
  module V2
    class OrganizationUsersController < BaseController

      before_action :require_organization!
      before_action :require_permission!

      # GET /api/v2/organizations/:permalink/users
      def index
        users = @organization.users.order(:last_name, :first_name)
        result = paginate(users)
        render_paginated(
          UserSerializer.serialize_collection(result[:records]),
          result,
        )
      end

      # POST /api/v2/organizations/:permalink/users
      def create
        invite = UserInvite.new(email_address: params[:email_address])
        invite.organization_users.build(organization: @organization)

        if invite.save
          render_created({
            uuid: invite.uuid,
            email_address: invite.email_address,
            expires_at: invite.expires_at&.iso8601,
          })
        else
          render_validation_error(invite)
        end
      end

      # DELETE /api/v2/organizations/:permalink/users/:uuid
      def destroy
        user = @organization.users.find_by_uuid!(params[:uuid])
        assignment = @organization.organization_users.find_by(user: user)

        if assignment
          assignment.destroy!
          render_destroyed
        else
          render_not_found("User not found in this organization")
        end
      end

      private

      def require_permission!
        if action_name == "index"
          require_any_permission!("users.read", "organizations.read")
        else
          require_permission!("users.manage")
        end
      end

    end
  end
end
