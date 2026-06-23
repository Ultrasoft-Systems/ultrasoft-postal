# frozen_string_literal: true

module API
  module V2
    class IpPoolRulesController < BaseController

      before_action :require_organization!
      before_action :require_server!
      before_action :check_read_permission!

      # GET /api/v2/org/:org_permalink/servers/:permalink/ip_pool_rules
      def index
        rules = @server.ip_pool_rules.includes(:ip_pool).order(created_at: :desc)
        result = paginate(rules)
        render_paginated(
          result[:records].map { |r| serialize_rule(r) },
          result,
        )
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/ip_pool_rules
      def create
        rule = @server.ip_pool_rules.build(rule_params)

        if rule.save
          render_created serialize_rule(rule)
        else
          render_validation_error(rule)
        end
      end

      # PATCH /api/v2/org/:org_permalink/servers/:permalink/ip_pool_rules/:uuid
      def update
        rule = find_rule

        if rule.update(rule_params)
          render_success serialize_rule(rule)
        else
          render_validation_error(rule)
        end
      end

      # DELETE /api/v2/org/:org_permalink/servers/:permalink/ip_pool_rules/:uuid
      def destroy
        rule = find_rule
        rule.destroy!
        render_destroyed
      end

      private

      def find_rule
        @server.ip_pool_rules.find_by_uuid!(params[:uuid])
      end

      def rule_params
        params.permit(:ip_pool_id, :from_address, :to_address, :smtp_auth_key)
      end

      def serialize_rule(rule)
        {
          uuid: rule.uuid,
          ip_pool_name: rule.ip_pool&.name,
          ip_pool_uuid: rule.ip_pool&.uuid,
          from_address: rule.from_address,
          to_address: rule.to_address,
          smtp_auth_key: rule.smtp_auth_key,
          server_permalink: rule.owner&.permalink,
          created_at: rule.created_at&.iso8601,
          updated_at: rule.updated_at&.iso8601,
        }
      end

      def check_read_permission!
        if action_name.in?(%w[index])
          require_any_permission!("ip_pools.read", "servers.read")
        else
          require_permission!("ip_pools.write")
        end
      end

    end
  end
end
