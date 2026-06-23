# frozen_string_literal: true

module API
  module V2
    class IpPoolsController < BaseController

      before_action :require_permission!

      # GET /api/v2/ip_pools
      def index
        pools = IPPool.order(:name)
        result = paginate(pools)
        render_paginated(
          result[:records].map { |p| serialize_ip_pool(p) },
          result,
        )
      end

      # GET /api/v2/ip_pools/:id
      def show
        pool = find_pool
        render_success serialize_ip_pool(pool, include_addresses: true)
      end

      # POST /api/v2/ip_pools
      def create
        pool = IPPool.new(pool_params)

        if pool.save
          render_created serialize_ip_pool(pool)
        else
          render_validation_error(pool)
        end
      end

      # PATCH /api/v2/ip_pools/:id
      def update
        pool = find_pool

        if pool.update(pool_params)
          render_success serialize_ip_pool(pool)
        else
          render_validation_error(pool)
        end
      end

      # DELETE /api/v2/ip_pools/:id
      def destroy
        pool = find_pool
        pool.destroy!
        render_destroyed
      end

      private

      def find_pool
        IPPool.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found("IP pool not found")
        nil
      end

      def pool_params
        params.permit(:name, :default)
      end

      def serialize_ip_pool(pool, include_addresses: false)
        result = {
          id: pool.id,
          name: pool.name,
          uuid: pool.uuid,
          default: pool.default?,
          ip_address_count: pool.ip_addresses.count,
          created_at: pool.created_at&.iso8601,
          updated_at: pool.updated_at&.iso8601,
        }

        if include_addresses
          result[:ip_addresses] = pool.ip_addresses.map do |addr|
            {
              uuid: addr.uuid,
              ipv4: addr.ipv4,
              ipv6: addr.ipv6,
              hostname: addr.hostname,
              priority: addr.priority,
              created_at: addr.created_at&.iso8601,
            }
          end
        end

        result
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
