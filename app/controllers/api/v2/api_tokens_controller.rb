# frozen_string_literal: true

module API
  module V2
    class ApiTokensController < BaseController

      before_action :require_permission!

      # GET /api/v2/auth/tokens
      def index
        tokens = APIToken.order(:name)
        result = paginate(tokens)

        serialized = result[:records].map { |t| serialize_token(t) }
        render_paginated(serialized, result)
      end

      # POST /api/v2/auth/tokens
      def create
        token = APIToken.new(token_params)
        token.assign_attributes(
          user: resolve_token_target[:user],
          organization: resolve_token_target[:organization],
          server: resolve_token_target[:server],
        )

        if token.save
          render_created serialize_token(token, reveal_token: true)
        else
          render_validation_error(token)
        end
      end

      # DELETE /api/v2/auth/tokens/:uuid
      def destroy
        token = APIToken.find_by_uuid!(params[:uuid])
        token.revoke
        render_destroyed
      rescue ActiveRecord::RecordNotFound
        render_not_found("API token not found")
      end

      private

      def serialize_token(token, reveal_token: false)
        result = {
          uuid: token.uuid,
          name: token.name,
          scope: token.scope,
          permissions: token.permissions,
          active: token.active?,
          last_used_at: token.last_used_at&.iso8601,
          expires_at: token.expires_at&.iso8601,
          created_at: token.created_at&.iso8601,
        }
        result[:token] = token.token if reveal_token
        result
      end

      def token_params
        params.permit(:name, :scope, :expires_at, permissions: [])
      end

      def resolve_token_target
        case params[:scope]
        when "user"
          { user: User.find_by_uuid!(params[:user_uuid]) } if params[:user_uuid].present?
        when "organization"
          { organization: Organization.present.find_by_permalink!(params[:org_permalink]) } if params[:org_permalink].present?
        when "server"
          if params[:org_permalink].present? && params[:server_permalink].present?
            org = Organization.present.find_by_permalink!(params[:org_permalink])
            { server: org.servers.present.find_by_permalink!(params[:server_permalink]) }
          end
        end || {}
      end

      def require_permission!
        require_permission!("api_tokens.manage")
      end

    end
  end
end
