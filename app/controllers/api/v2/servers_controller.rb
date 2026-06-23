# frozen_string_literal: true

module API
  module V2
    class ServersController < BaseController

      before_action :require_organization!
      before_action :require_permission!, only: [:index, :show, :queue, :limits, :stats]
      before_action :require_write_permission!, only: [:create, :update, :destroy]
      before_action :require_suspend_permission!, only: [:suspend, :unsuspend]

      # GET /api/v2/org/:org_permalink/servers
      def index
        servers = @organization.servers.present.order(:name)
        result = paginate(servers)
        render_paginated(
          ServerSerializer.serialize_collection(result[:records]),
          result,
        )
      end

      # GET /api/v2/org/:org_permalink/servers/:permalink
      def show
        server = find_server
        render_success ServerSerializer.serialize(
          server,
          include: params[:include]&.split(",")&.map(&:to_sym),
          context: { show_sensitive: has_permission?("servers.write") },
        )
      end

      # POST /api/v2/org/:org_permalink/servers
      def create
        server = @organization.servers.build(server_params)

        if server.save
          render_created ServerSerializer.serialize(server, context: { show_sensitive: true })
        else
          render_validation_error(server)
        end
      end

      # PATCH /api/v2/org/:org_permalink/servers/:permalink
      def update
        server = find_server

        if server.update(server_params)
          render_success ServerSerializer.serialize(server)
        else
          render_validation_error(server)
        end
      end

      # DELETE /api/v2/org/:org_permalink/servers/:permalink
      def destroy
        server = find_server
        server.soft_destroy
        render_destroyed
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/suspend
      def suspend
        server = find_server
        reason = params[:reason].presence || "Suspended via API"

        if server.suspend(reason)
          render_success ServerSerializer.serialize(server)
        else
          render_error("Failed to suspend server", details: server.errors.full_messages)
        end
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/unsuspend
      def unsuspend
        server = find_server
        server.unsuspend
        render_success ServerSerializer.serialize(server)
      end

      # GET /api/v2/org/:org_permalink/servers/:permalink/queue
      def queue
        server = find_server
        render_success({
          queue_size: server.queue_size,
          held_messages: server.held_messages,
          send_volume: server.send_volume,
        })
      end

      # GET /api/v2/org/:org_permalink/servers/:permalink/limits
      def limits
        server = find_server
        render_success({
          send_limit: server.send_limit,
          send_volume: server.send_volume,
          approaching: server.send_limit_approaching?,
          exceeded: server.send_limit_exceeded?,
          usage_percent: server.send_limit ? ((server.send_volume.to_f / server.send_limit) * 100).round(2) : 0,
        })
      end

      # GET /api/v2/org/:org_permalink/servers/:permalink/stats
      def stats
        server = find_server
        stats = server.throughput_stats
        total_domains, unverified_domains, bad_dns_domains = server.domain_stats

        render_success({
          throughput: stats,
          message_rate: server.message_rate&.round(2),
          bounce_rate: server.bounce_rate&.round(2),
          domains: {
            total: total_domains,
            unverified: unverified_domains,
            bad_dns: bad_dns_domains,
          },
        })
      end

      private

      def find_server
        server = @organization.servers.present.find_by_permalink!(params[:permalink])
        server
      rescue ActiveRecord::RecordNotFound
        render_not_found("Server not found")
        nil
      end

      def server_params
        params.permit(
          :name, :mode, :send_limit, :spam_threshold, :spam_failure_threshold,
          :outbound_spam_threshold, :postmaster_address, :privacy_mode,
          :allow_sender, :log_smtp_data, :message_retention_days,
          :raw_message_retention_days, :raw_message_retention_size,
          :ip_pool_id, :domains_not_to_click_track
        )
      end

      def require_permission!
        require_any_permission!("servers.read", "organizations.read")
      end

      def require_write_permission!
        require_permission!("servers.write")
      end

      def require_suspend_permission!
        require_permission!("servers.suspend")
      end

    end
  end
end
