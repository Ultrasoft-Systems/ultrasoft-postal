# frozen_string_literal: true

module API
  module V2
    class SuppressionsController < BaseController

      before_action :require_server!
      before_action :require_permission!

      # GET /api/v2/suppressions
      def index
        suppressions = @server.message_db.suppression_list.all
        result = paginate_array(suppressions)
        render_paginated(result[:records], result)
      end

      # POST /api/v2/suppressions
      def create
        type = params[:type] || "recipient"
        value = params[:value]

        if value.blank?
          render_error("`value` parameter is required", code: "MISSING_VALUE")
          return
        end

        added = @server.message_db.suppression_list.add(type.to_sym, value, reason: params[:reason])

        if added
          render_created({
            type: type,
            value: value,
            reason: params[:reason],
            added: true,
          })
        else
          render_success({
            type: type,
            value: value,
            added: false,
            message: "Already exists in suppression list",
          })
        end
      end

      # DELETE /api/v2/suppressions
      def destroy
        type = params[:type] || "recipient"
        value = params[:value]

        if value.blank?
          render_error("`value` parameter is required", code: "MISSING_VALUE")
          return
        end

        removed = @server.message_db.suppression_list.remove(type.to_sym, value)

        render_success({
          type: type,
          value: value,
          removed: removed,
        })
      end

      private

      def require_permission!
        if action_name == "index"
          require_permission!("suppressions.read")
        else
          require_permission!("suppressions.write")
        end
      end

    end
  end
end
