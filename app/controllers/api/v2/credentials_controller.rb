# frozen_string_literal: true

module API
  module V2
    class CredentialsController < BaseController

      before_action :require_organization!
      before_action :require_server!
      before_action :require_permission!

      # GET /api/v2/org/:org_permalink/servers/:permalink/credentials
      def index
        credentials = @server.credentials.order(:type, :name)
        result = paginate(credentials)
        render_paginated(
          CredentialSerializer.serialize_collection(result[:records]),
          result,
        )
      end

      # GET /api/v2/org/:org_permalink/servers/:permalink/credentials/:uuid
      def show
        credential = find_credential
        render_success CredentialSerializer.serialize(
          credential,
          context: { show_sensitive: has_permission?("credentials.write") },
        )
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/credentials
      def create
        credential = @server.credentials.build(credential_params)

        if credential.save
          render_created CredentialSerializer.serialize(credential, context: { show_sensitive: true })
        else
          render_validation_error(credential)
        end
      end

      # PATCH /api/v2/org/:org_permalink/servers/:permalink/credentials/:uuid
      def update
        credential = find_credential

        if credential.update(credential_update_params)
          render_success CredentialSerializer.serialize(credential)
        else
          render_validation_error(credential)
        end
      end

      # DELETE /api/v2/org/:org_permalink/servers/:permalink/credentials/:uuid
      def destroy
        credential = find_credential
        credential.destroy!
        render_destroyed
      end

      private

      def find_credential
        @server.credentials.find_by_uuid!(params[:uuid])
      end

      def credential_params
        params.permit(:type, :name, :hold, :key)
      end

      def credential_update_params
        params.permit(:name, :hold)
      end

      def require_permission!
        if action_name == "index" || action_name == "show"
          require_any_permission!("credentials.read", "servers.read")
        else
          require_permission!("credentials.write")
        end
      end

    end
  end
end
