# frozen_string_literal: true

module API
  module V2
    class TrackDomainsController < BaseController

      before_action :require_organization!
      before_action :require_server!
      before_action :require_permission!

      # GET /api/v2/org/:org_permalink/servers/:permalink/track_domains
      def index
        domains = @server.track_domains.order(:name)
        result = paginate(domains)
        render_paginated(
          result[:records].map { |d| serialize_track_domain(d) },
          result,
        )
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/track_domains
      def create
        domain = @server.track_domains.build(domain_params)

        if domain.save
          render_created serialize_track_domain(domain)
        else
          render_validation_error(domain)
        end
      end

      # PATCH /api/v2/org/:org_permalink/servers/:permalink/track_domains/:uuid
      def update
        domain = find_domain

        if domain.update(domain_params)
          render_success serialize_track_domain(domain)
        else
          render_validation_error(domain)
        end
      end

      # DELETE /api/v2/org/:org_permalink/servers/:permalink/track_domains/:uuid
      def destroy
        domain = find_domain
        domain.destroy!
        render_destroyed
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/track_domains/:uuid/toggle_ssl
      def toggle_ssl
        domain = find_domain
        domain.toggle_ssl
        render_success serialize_track_domain(domain)
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/track_domains/:uuid/check
      def check
        domain = find_domain
        domain.check_dns

        render_success({
          uuid: domain.uuid,
          name: domain.name,
          ssl_enabled: domain.ssl_enabled?,
          dns_checked_at: domain.dns_checked_at&.iso8601,
          dns_ok: domain.dns_ok?,
        })
      end

      private

      def find_domain
        @server.track_domains.find_by_uuid!(params[:uuid])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Track domain not found")
        nil
      end

      def domain_params
        params.permit(:name)
      end

      def serialize_track_domain(domain)
        {
          uuid: domain.uuid,
          name: domain.name,
          ssl_enabled: domain.ssl_enabled?,
          dns_checked_at: domain.dns_checked_at&.iso8601,
          server_permalink: domain.server&.permalink,
          created_at: domain.created_at&.iso8601,
          updated_at: domain.updated_at&.iso8601,
        }
      end

      def require_permission!
        if action_name.in?(%w[index])
          require_any_permission!("servers.read")
        else
          require_permission!("servers.write")
        end
      end

    end
  end
end
