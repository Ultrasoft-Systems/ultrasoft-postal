# frozen_string_literal: true

module API
  module V2
    class DomainsController < BaseController

      before_action :require_organization!
      before_action :require_server!
      before_action :require_permission!, only: [:index, :show]
      before_action :require_write_permission!, only: [:create, :destroy]
      before_action :require_verify_permission!, only: [:verify, :check_dns]

      # GET /api/v2/org/:org_permalink/servers/:permalink/domains
      def index
        domains = @server.domains.order(:name)
        result = paginate(domains)
        render_paginated(
          DomainSerializer.serialize_collection(result[:records]),
          result,
        )
      end

      # GET /api/v2/org/:org_permalink/servers/:permalink/domains/:uuid
      def show
        domain = find_domain
        render_success DomainSerializer.serialize(domain)
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/domains
      def create
        owner = params[:organization_level] ? @organization : @server
        domain = owner.domains.build(domain_params)

        if domain.save
          render_created DomainSerializer.serialize(domain)
        else
          render_validation_error(domain)
        end
      end

      # DELETE /api/v2/org/:org_permalink/servers/:permalink/domains/:uuid
      def destroy
        domain = find_domain
        domain.destroy!
        render_destroyed
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/domains/:uuid/verify
      def verify
        domain = find_domain

        case domain.verification_method
        when "DNS"
          if domain.verify_with_dns
            render_success DomainSerializer.serialize(domain)
          else
            render_error(
              "DNS verification failed — TXT record not found",
              code: "VERIFICATION_FAILED",
              details: {
                verification_string: domain.dns_verification_string,
                expected_record: "#{domain.name} TXT",
              },
            )
          end
        when "Email"
          render_error(
            "Email verification must be completed via the web interface",
            code: "EMAIL_VERIFICATION_UNSUPPORTED",
          )
        else
          render_error("Unknown verification method: #{domain.verification_method}")
        end
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/domains/:uuid/check_dns
      def check_dns
        domain = find_domain
        domain.check_dns

        render_success({
          spf: { status: domain.spf_status, error: domain.spf_error },
          dkim: { status: domain.dkim_status, error: domain.dkim_error },
          mx: { status: domain.mx_status, error: domain.mx_error },
          return_path: { status: domain.return_path_status, error: domain.return_path_error },
          checked_at: domain.dns_checked_at&.iso8601,
          all_ok: domain.dns_ok?,
        })
      end

      private

      def find_domain
        @server.domains.find_by_uuid!(params[:uuid])
      end

      def domain_params
        params.permit(:name, :verification_method, :outgoing, :incoming, :use_for_any)
      end

      def require_permission!
        require_any_permission!("domains.read", "servers.read")
      end

      def require_write_permission!
        require_permission!("domains.write")
      end

      def require_verify_permission!
        require_permission!("domains.verify")
      end

    end
  end
end
