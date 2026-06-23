# frozen_string_literal: true

module API
  module V2
    class OrganizationDomainsController < BaseController

      before_action :require_organization!
      before_action :check_permission!

      # POST /api/v2/organizations/:permalink/domains
      def create
        skip_verify = params.delete(:skip_verification)
        domain = @organization.domains.build(domain_params)
        if domain.save
          domain.update!(verified_at: Time.current) if skip_verify && has_permission?("*")
          render_created DomainSerializer.serialize(domain)
        else
          render_validation_error(domain)
        end
      end

      # DELETE /api/v2/organizations/:permalink/domains/:uuid
      def destroy
        domain = find_domain
        domain.destroy!
        render_destroyed
      end

      # POST /api/v2/organizations/:permalink/domains/:uuid/verify
      def verify
        domain = find_domain
        if params[:force] && has_permission?("*")
          domain.update!(verified_at: Time.current)
          render_success DomainSerializer.serialize(domain)
        elsif domain.verify_with_dns
          render_success DomainSerializer.serialize(domain)
        else
          render_error("DNS verification failed",
                       code: "VERIFICATION_FAILED",
                       details: { verification_string: domain.dns_verification_string })
        end
      end

      # POST /api/v2/organizations/:permalink/domains/:uuid/check_dns
      def check_dns
        domain = find_domain
        domain.check_dns
        render_success({
          spf: { status: domain.spf_status, error: domain.spf_error },
          dkim: { status: domain.dkim_status, error: domain.dkim_error },
          mx: { status: domain.mx_status, error: domain.mx_error },
          return_path: { status: domain.return_path_status, error: domain.return_path_error },
          all_ok: domain.dns_ok?,
        })
      end

      private

      def find_domain
        @organization.domains.find_by_uuid!(params[:uuid])
      end

      def require_organization!
        permalink = params[:organization_permalink] || params[:org_permalink]
        @organization = Organization.present.find_by_permalink!(permalink)
      end

      def domain_params
        params.permit(:name, :verification_method, :outgoing, :incoming, :use_for_any, :skip_verification)
      end

      def check_permission!
        if action_name.in?(%w[create destroy])
          require_permission!("domains.write")
        else
          require_any_permission!("domains.read", "servers.read")
        end
      end

    end
  end
end
