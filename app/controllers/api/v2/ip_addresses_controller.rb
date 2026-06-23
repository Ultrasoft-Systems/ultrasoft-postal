# frozen_string_literal: true

module API
  module V2
    class IpAddressesController < BaseController

      before_action :require_permission!

      # GET /api/v2/ip_pools/:ip_pool_id/ip_addresses
      def index
        pool = find_pool
        addresses = pool.ip_addresses.order(:ipv4)
        result = paginate(addresses)
        render_paginated(
          result[:records].map { |a| serialize_address(a) },
          result,
        )
      end

      # POST /api/v2/ip_pools/:ip_pool_id/ip_addresses
      def create
        pool = find_pool
        address = pool.ip_addresses.build(address_params)

        if address.save
          render_created serialize_address(address)
        else
          render_validation_error(address)
        end
      end

      # PATCH /api/v2/ip_pools/:ip_pool_id/ip_addresses/:uuid
      def update
        address = find_address
        if address.update(address_params)
          render_success serialize_address(address)
        else
          render_validation_error(address)
        end
      end

      # DELETE /api/v2/ip_pools/:ip_pool_id/ip_addresses/:uuid
      def destroy
        address = find_address
        address.destroy!
        render_destroyed
      end

      private

      def find_pool
        IPPool.find(params[:ip_pool_id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("IP pool not found")
        nil
      end

      def find_address
        pool = find_pool
        return unless pool

        pool.ip_addresses.find_by_uuid!(params[:uuid])
      rescue ActiveRecord::RecordNotFound
        render_not_found("IP address not found")
        nil
      end

      def address_params
        params.permit(:ipv4, :ipv6, :hostname, :priority)
      end

      def serialize_address(address)
        {
          uuid: address.uuid,
          ipv4: address.ipv4,
          ipv6: address.ipv6,
          hostname: address.hostname,
          priority: address.priority,
          ip_pool_name: address.ip_pool&.name,
          created_at: address.created_at&.iso8601,
          updated_at: address.updated_at&.iso8601,
        }
      end

      def require_permission!
        if action_name.in?(%w[index show])
          require_permission!("ip_pools.read")
        else
          require_permission!("ip_pools.write")
        end
      end

    end
  end
end
