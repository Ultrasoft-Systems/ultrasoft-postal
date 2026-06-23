# frozen_string_literal: true

module API
  module V2
    class UsersController < BaseController

      before_action :require_permission!

      # GET /api/v2/users
      def index
        users = User.order(:last_name, :first_name)
        result = paginate(users)
        render_paginated(
          UserSerializer.serialize_collection(result[:records]),
          result,
        )
      end

      # GET /api/v2/users/:uuid
      def show
        user = find_user
        render_success UserSerializer.serialize(user)
      end

      # POST /api/v2/users
      def create
        user = User.new(user_params)

        if user.save
          render_created UserSerializer.serialize(user)
        else
          render_validation_error(user)
        end
      end

      # PATCH /api/v2/users/:uuid
      def update
        user = find_user

        if user.update(user_update_params)
          render_success UserSerializer.serialize(user)
        else
          render_validation_error(user)
        end
      end

      # DELETE /api/v2/users/:uuid
      def destroy
        user = find_user
        user.destroy!
        render_destroyed
      end

      # POST /api/v2/users/invite
      def invite
        invite = UserInvite.new(email_address: params[:email_address])

        if params[:organization_permalink].present?
          org = Organization.present.find_by_permalink!(params[:organization_permalink])
          invite.organization_users.build(organization: org)
        end

        if invite.save
          render_created({
            uuid: invite.uuid,
            email_address: invite.email_address,
            expires_at: invite.expires_at&.iso8601,
          })
        else
          render_validation_error(invite)
        end
      rescue ActiveRecord::RecordNotFound
        render_not_found("Organization not found")
      end

      private

      def find_user
        User.find_by_uuid!(params[:uuid])
      rescue ActiveRecord::RecordNotFound
        render_not_found("User not found")
        nil
      end

      def user_params
        params.permit(:first_name, :last_name, :email_address, :password, :admin, :time_zone)
      end

      def user_update_params
        params.permit(:first_name, :last_name, :email_address, :admin, :time_zone)
      end

      def require_permission!
        if action_name.in?(%w[index show])
          require_permission!("users.read")
        else
          require_permission!("users.manage")
        end
      end

    end
  end
end
