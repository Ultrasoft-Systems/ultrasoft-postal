# frozen_string_literal: true

module API
  module V2
    class OrganizationDomainsController < BaseController

      before_action :require_organization!
      before_action :check_permission!

      # DELETE /api/v2/organizations/:org_permalink/domains/:uuid
      def destroy
        domain = @organization.domains.find_by_uuid!(params[:uuid])
        domain.destroy!
        render_destroyed
      end

      private

      def require_organization!
        permalink = params[:organization_permalink] || params[:org_permalink]
        @organization = Organization.present.find_by_permalink!(permalink)
      end

      def check_permission!
        require_permission!("domains.write")
      end

    end
  end
end
