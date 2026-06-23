# frozen_string_literal: true

module API
  module V2
    module Endpoints
      class AddressController < BaseController

        before_action :require_organization!
        before_action :require_server!
        before_action :check_read_permission!

        def index
          endpoints = @server.address_endpoints.order(:address)
          result = paginate(endpoints)
          render_paginated(result[:records].map { |e| serialize_endpoint(e) }, result)
        end

        def show
          endpoint = find_endpoint
          render_success serialize_endpoint(endpoint)
        end

        def create
          endpoint = @server.address_endpoints.build(endpoint_params)
          if endpoint.save
            render_created serialize_endpoint(endpoint)
          else
            render_validation_error(endpoint)
          end
        end

        def update
          endpoint = find_endpoint
          if endpoint.update(endpoint_params)
            render_success serialize_endpoint(endpoint)
          else
            render_validation_error(endpoint)
          end
        end

        def destroy
          endpoint = find_endpoint
          endpoint.destroy!
          render_destroyed
        end

        private

        def find_endpoint
          @server.address_endpoints.find_by_uuid!(params[:uuid])
        end

        def endpoint_params
          params.permit(:name, :address)
        end

        def serialize_endpoint(endpoint)
          {
            uuid: endpoint.uuid,
            name: endpoint.name,
            address: endpoint.address,
            server_permalink: endpoint.server&.permalink,
            created_at: endpoint.created_at&.iso8601,
            updated_at: endpoint.updated_at&.iso8601,
          }
        end

        def check_read_permission!
          if action_name.in?(%w[index show])
            require_any_permission!("endpoints.read", "servers.read")
          else
            require_permission!("endpoints.write")
          end
        end

      end
    end
  end
end
