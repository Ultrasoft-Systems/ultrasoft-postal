# frozen_string_literal: true

module API
  module V2
    module Concerns
      # Audit logging concern for API v2 controllers.
      #
      # Logs every API request with structured data compatible with Postal's
      # existing Klogger setup. Mutations (POST/PATCH/PUT/DELETE) are logged at
      # INFO level; reads (GET) are logged at DEBUG level.
      #
      # Logged fields:
      #   - method, path, status, duration_ms
      #   - auth_type (api_token / credential / none)
      #   - token_scope, token_uuid (if applicable)
      #   - server_permalink, org_permalink
      #   - ip, user_agent
      #
      module AuditLoggable

        extend ActiveSupport::Concern

        included do
          around_action :audit_log_request
        end

        private

        def audit_log_request
          start_time = Time.now
          yield
        ensure
          log_api_request(start_time)
        end

        def log_api_request(start_time)
          duration_ms = ((Time.now - start_time) * 1000).round(2)
          status_code = response.status

          payload = {
            component: "api_v2",
            method: request.method,
            path: request.path,
            status: status_code,
            duration_ms: duration_ms,
            ip: request.remote_ip,
            auth_type: auth_type,
          }

          # Add auth-specific details
          if @current_api_token
            payload[:token_uuid] = @current_api_token.uuid
            payload[:token_scope] = @current_api_token.scope
            payload[:token_name] = @current_api_token.name
          elsif @current_credential
            payload[:credential_uuid] = @current_credential.uuid
            payload[:credential_type] = @current_credential.type
          end

          # Add resource context
          payload[:org_permalink] = @organization&.permalink if @organization
          payload[:server_permalink] = @server&.permalink if @server

          # Log at appropriate level
          if status_code >= 500
            logger.error payload.merge(message: "API error: #{request.method} #{request.path}")
          elsif status_code >= 400
            logger.warn payload.merge(message: "API client error: #{request.method} #{request.path}")
          elsif mutation_request?
            logger.info payload.merge(message: "API mutation: #{request.method} #{request.path}")
          else
            logger.debug payload.merge(message: "API request: #{request.method} #{request.path}")
          end
        rescue StandardError => e
          # Never let audit logging break the response
          Rails.logger.error "Audit logging failed: #{e.message}"
        end

        def auth_type
          if @current_api_token
            "api_token"
          elsif @current_credential
            "credential"
          else
            "none"
          end
        end

        def mutation_request?
          request.method.in?(%w[POST PATCH PUT DELETE])
        end

        def logger
          Postal.logger
        end

      end
    end
  end
end
