# frozen_string_literal: true

module API
  module V2
    # The API v2 base controller provides standardized authentication, permission
    # checking, pagination, and response formatting for all v2 API endpoints.
    #
    # Authentication is performed via the X-Postal-API-Key header. The token's
    # scope (user, organization, or server) determines what resources are
    # accessible. Legacy X-Server-API-Key is also supported for backward
    # compatibility with a restricted permission set.
    #
    # All responses use a consistent JSON envelope:
    #
    #   Success:  { success: true,  data: ..., meta: { page, per_page, total, total_pages } }
    #   Error:    { success: false, error: "...", code: "ERROR_CODE", details: ... }
    #
    class BaseController < ActionController::Base

      include Concerns::RateLimitable
      include Concerns::AuditLoggable

      skip_before_action :set_browser_id
      skip_before_action :verify_authenticity_token

      before_action :set_default_response_format
      before_action :authenticate!
      before_action :set_pagination_defaults

      rescue_from ActiveRecord::RecordNotFound, with: :render_record_not_found
      rescue_from Postal::MessageDB::Message::NotFound, with: :render_record_not_found

      # ---------------------------------------------------------------------------
      # Permission catalog — all available API permission keys
      # ---------------------------------------------------------------------------

      PERMISSION_CATALOG = {
        "organizations.read" => "View organizations",
        "organizations.write" => "Create, update, and delete organizations",
        "servers.read" => "View servers and their configuration",
        "servers.write" => "Create, update, and delete servers",
        "servers.suspend" => "Suspend and unsuspend servers",
        "domains.read" => "View domains and DNS status",
        "domains.write" => "Create and delete domains",
        "domains.verify" => "Verify domains and trigger DNS checks",
        "credentials.read" => "View credentials",
        "credentials.write" => "Create, update, and delete credentials",
        "routes.read" => "View routes",
        "routes.write" => "Create, update, and delete routes",
        "endpoints.read" => "View endpoints",
        "endpoints.write" => "Create, update, and delete endpoints",
        "webhooks.read" => "View webhooks and their history",
        "webhooks.write" => "Create, update, and delete webhooks",
        "messages.read" => "View messages (incoming, outgoing, held)",
        "messages.send" => "Send messages via the API",
        "messages.manage" => "Retry, cancel holds, and remove messages from queue",
        "suppressions.read" => "View the suppression list",
        "suppressions.write" => "Add and remove entries from the suppression list",
        "ip_pools.read" => "View IP pools and IP addresses",
        "ip_pools.write" => "Create, update, and delete IP pools and addresses",
        "users.read" => "View users",
        "users.manage" => "Create, update, delete users and send invitations",
        "stats.read" => "View statistics (throughput, bounce rate, etc.)",
        "api_tokens.manage" => "Create and revoke API tokens",
      }.freeze

      # ---------------------------------------------------------------------------
      # Authentication
      # ---------------------------------------------------------------------------

      private

      def set_default_response_format
        request.format = :json
      end

      def authenticate!
        if token_from_header.present?
          authenticate_with_api_token
        elsif legacy_api_key.present?
          authenticate_with_legacy_key
        else
          render_authentication_error("No API key provided. Use X-Postal-API-Key header.")
        end
      end

      def authenticate_with_api_token
        @current_api_token = APIToken.find_by_token(token_from_header)

        if @current_api_token.nil?
          render_authentication_error("The API token provided was not valid or has expired.")
          return
        end

        @current_api_token.use
        resolve_token_scope
      end

      def authenticate_with_legacy_key
        key = legacy_api_key
        credential = Credential.where(type: "API", key: key).first

        if credential.nil?
          render_authentication_error("The API key provided was not valid.")
          return
        end

        if credential.server.suspended?
          render_forbidden("The server associated with this API key is suspended.")
          return
        end

        credential.use
        @current_credential = credential
        @current_server = credential.server
      end

      def resolve_token_scope
        case @current_api_token.scope
        when "server"
          @current_server = @current_api_token.server
        when "organization"
          @current_organization = @current_api_token.organization
        when "user"
          @current_user = @current_api_token.user
        end
      end

      # ---------------------------------------------------------------------------
      # Permission checking
      # ---------------------------------------------------------------------------

      def require_permission!(key)
        # Legacy credentials get send+read on their server only
        if @current_credential
          allowed = %w[messages.read messages.send].include?(key)
          render_forbidden("This API key does not have permission: #{key}") unless allowed
          return
        end

        return if @current_api_token&.has_permission?(key)

        render_forbidden("This API token does not have permission: #{key}")
      end

      def require_any_permission!(*keys)
        return if keys.any? { |k| has_permission?(k) }

        render_forbidden("This API token does not have any of the required permissions: #{keys.join(', ')}")
      end

      def has_permission?(key)
        if @current_credential
          %w[messages.read messages.send].include?(key)
        else
          @current_api_token&.has_permission?(key)
        end
      end

      # ---------------------------------------------------------------------------
      # Server resolution (from auth scope or URL params)
      # ---------------------------------------------------------------------------

      def resolve_server
        if @current_server
          @server = @current_server
        elsif @current_organization
          @server = @current_organization.servers.present.find_by_permalink!(params[:server_permalink])
        elsif @current_api_token&.scope == "user"
          org = @current_user.organizations_scope.find_by_permalink!(params[:org_permalink])
          @server = org.servers.present.find_by_permalink!(params[:server_permalink])
        end
      end

      def resolve_organization
        if @current_organization
          @organization = @current_organization
        elsif params[:org_permalink].present?
          # URL parameter takes precedence — enables wildcard tokens
          # to manage multiple organizations
          @organization = Organization.present.find_by_permalink!(params[:org_permalink])
        elsif @current_server
          @organization = @current_server.organization
        elsif @current_api_token&.scope == "user"
          @organization = @current_user.organizations_scope.find_by_permalink!(params[:org_permalink])
        end
      end

      def require_server!
        resolve_server
        render_not_found("Server not found") unless @server
      end

      def require_organization!
        resolve_organization
        render_not_found("Organization not found") unless @organization
      end

      # ---------------------------------------------------------------------------
      # Pagination
      # ---------------------------------------------------------------------------

      def set_pagination_defaults
        @page = [(params[:page] || 1).to_i, 1].max
        @per_page = [[(params[:per_page] || 30).to_i, 1].max, 200].min
      end

      def paginate(scope)
        total = scope.count
        total_pages, remainder = total.divmod(@per_page)
        total_pages += 1 if remainder.positive?

        records = scope.offset((@page - 1) * @per_page).limit(@per_page)

        {
          records: records,
          meta: {
            page: @page,
            per_page: @per_page,
            total: total,
            total_pages: total_pages,
          },
        }
      end

      def paginate_array(array)
        total = array.size
        total_pages, remainder = total.divmod(@per_page)
        total_pages += 1 if remainder.positive?

        records = array[((@page - 1) * @per_page), @per_page] || []

        {
          records: records,
          meta: {
            page: @page,
            per_page: @per_page,
            total: total,
            total_pages: total_pages,
          },
        }
      end

      # ---------------------------------------------------------------------------
      # Response rendering
      # ---------------------------------------------------------------------------

      def render_success(data, meta: {}, status: :ok)
        response = { success: true, data: data }
        response[:meta] = meta if meta.present?
        render json: response, status: status
      end

      def render_paginated(data, pagination_result)
        response = {
          success: true,
          data: data,
          meta: pagination_result[:meta],
        }
        render json: response, status: :ok
      end

      def render_created(data)
        render_success(data, status: :created)
      end

      def render_destroyed
        render_success({ deleted: true }, status: :ok)
      end

      def render_no_content
        head :no_content
      end

      def render_error(message, code: nil, status: :unprocessable_entity, details: nil)
        response = { success: false, error: message }
        response[:code] = code if code
        response[:details] = details if details
        render json: response, status: status
      end

      def render_validation_error(object)
        render_error(
          "Validation failed",
          code: "VALIDATION_ERROR",
          status: :unprocessable_entity,
          details: object.errors.map { |e| { field: e.attribute, message: e.full_message } },
        )
      end

      def render_not_found(message = "Resource not found")
        render_error(message, code: "NOT_FOUND", status: :not_found)
      end

      def render_record_not_found
        render_not_found
      end

      def render_forbidden(message = "You do not have permission to perform this action")
        render_error(message, code: "FORBIDDEN", status: :forbidden)
      end

      def render_authentication_error(message = "Authentication required")
        render_error(message, code: "UNAUTHORIZED", status: :unauthorized)
      end

      def render_rate_limited(message = "Too many requests")
        render_error(message, code: "RATE_LIMITED", status: :too_many_requests)
      end

      # ---------------------------------------------------------------------------
      # Parameter helpers
      # ---------------------------------------------------------------------------

      def token_from_header
        request.headers["X-Postal-API-Key"].presence
      end

      def legacy_api_key
        request.headers["X-Server-API-Key"].presence
      end

      # Extract and parse JSON request body
      def json_body
        @json_body ||= begin
          return {} unless request.content_type&.include?("application/json")

          JSON.parse(request.body.read)
        rescue JSON::ParserError
          {}
        end
      end

      # Safely permit parameters from either JSON body or form params
      def safe_params(*keys)
        if request.content_type&.include?("application/json")
          json_body.slice(*keys.map(&:to_s))
        else
          params.slice(*keys)
        end
      end

      # ---------------------------------------------------------------------------
      # Current context accessors
      # ---------------------------------------------------------------------------

      attr_reader :current_api_token
      attr_reader :current_credential
      attr_reader :current_server
      attr_reader :current_organization
      attr_reader :current_user

    end
  end
end
