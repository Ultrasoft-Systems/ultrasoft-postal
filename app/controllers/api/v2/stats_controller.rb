# frozen_string_literal: true

module API
  module V2
    class StatsController < BaseController

      before_action :require_permission!

      # GET /api/v2/stats/server/:org_permalink/:server_permalink
      def server
        org = find_organization
        server = org.servers.present.find_by_permalink!(params[:server_permalink])

        stats = server.throughput_stats
        total, unverified, bad_dns = server.domain_stats

        render_success({
          throughput: stats,
          message_rate: server.message_rate&.round(2),
          bounce_rate: server.bounce_rate&.round(2),
          queue_size: server.queue_size,
          held_messages: server.held_messages,
          send_volume: server.send_volume,
          send_limit: server.send_limit,
          domains: {
            total: total,
            unverified: unverified,
            bad_dns: bad_dns,
          },
        })
      rescue ActiveRecord::RecordNotFound
        render_not_found("Server not found")
      end

      # GET /api/v2/stats/organization/:org_permalink
      def organization
        org = find_organization
        servers = org.servers.present

        server_stats = servers.map do |server|
          {
            permalink: server.permalink,
            name: server.name,
            message_rate: server.message_rate&.round(2),
            bounce_rate: server.bounce_rate&.round(2),
            queue_size: server.queue_size,
            status: server.status,
          }
        end

        render_success({
          organization: org.permalink,
          total_servers: servers.count,
          servers: server_stats,
        })
      rescue ActiveRecord::RecordNotFound
        render_not_found("Organization not found")
      end

      private

      def find_organization
        if @current_user&.admin? || @current_api_token&.has_permission?("*")
          Organization.present.find_by_permalink!(params[:org_permalink])
        elsif @current_user
          @current_user.organizations_scope.find_by_permalink!(params[:org_permalink])
        else
          Organization.present.find_by_permalink!(params[:org_permalink])
        end
      end

      def require_permission!
        require_permission!("stats.read")
      end

    end
  end
end
