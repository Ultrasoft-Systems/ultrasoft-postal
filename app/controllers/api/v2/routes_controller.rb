# frozen_string_literal: true

module API
  module V2
    class RoutesController < BaseController

      before_action :require_organization!
      before_action :require_server!
      before_action :require_permission!

      # GET /api/v2/org/:org_permalink/servers/:permalink/routes
      def index
        routes = @server.routes.includes(:domain, :endpoint).order(:name)
        result = paginate(routes)
        render_paginated(
          RouteSerializer.serialize_collection(result[:records]),
          result,
        )
      end

      # GET /api/v2/org/:org_permalink/servers/:permalink/routes/:uuid
      def show
        route = find_route
        render_success RouteSerializer.serialize(route)
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/routes
      def create
        route = @server.routes.build(route_params)

        if params[:additional_endpoints].present?
          route.additional_route_endpoints_array = Array(params[:additional_endpoints])
        end

        if route.save
          render_created RouteSerializer.serialize(route)
        else
          render_validation_error(route)
        end
      end

      # PATCH /api/v2/org/:org_permalink/servers/:permalink/routes/:uuid
      def update
        route = find_route

        if params[:additional_endpoints].present?
          route.additional_route_endpoints_array = Array(params[:additional_endpoints])
        end

        if route.update(route_params)
          render_success RouteSerializer.serialize(route)
        else
          render_validation_error(route)
        end
      end

      # DELETE /api/v2/org/:org_permalink/servers/:permalink/routes/:uuid
      def destroy
        route = find_route
        route.destroy!
        render_destroyed
      end

      private

      def find_route
        @server.routes.find_by_uuid!(params[:uuid])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Route not found")
        nil
      end

      def route_params
        params.permit(:name, :domain_id, :_endpoint, :spam_mode)
      end

      def require_permission!
        if action_name == "index" || action_name == "show"
          require_any_permission!("routes.read", "servers.read")
        else
          require_permission!("routes.write")
        end
      end

    end
  end
end
