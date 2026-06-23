# frozen_string_literal: true

module API
  module V2
    class WebhooksController < BaseController

      before_action :require_organization!
      before_action :require_server!
      before_action :require_permission!

      # GET /api/v2/org/:org_permalink/servers/:permalink/webhooks
      def index
        webhooks = @server.webhooks.order(:name)
        result = paginate(webhooks)
        render_paginated(
          WebhookSerializer.serialize_collection(result[:records]),
          result,
        )
      end

      # GET /api/v2/org/:org_permalink/servers/:permalink/webhooks/:uuid
      def show
        webhook = find_webhook
        render_success WebhookSerializer.serialize(webhook)
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/webhooks
      def create
        webhook = @server.webhooks.build(webhook_params)

        if webhook.save
          render_created WebhookSerializer.serialize(webhook)
        else
          render_validation_error(webhook)
        end
      end

      # PATCH /api/v2/org/:org_permalink/servers/:permalink/webhooks/:uuid
      def update
        webhook = find_webhook

        if webhook.update(webhook_params)
          render_success WebhookSerializer.serialize(webhook)
        else
          render_validation_error(webhook)
        end
      end

      # DELETE /api/v2/org/:org_permalink/servers/:permalink/webhooks/:uuid
      def destroy
        webhook = find_webhook
        webhook.destroy!
        render_destroyed
      end

      # GET /api/v2/org/:org_permalink/servers/:permalink/webhooks/:uuid/history
      def history
        webhook = find_webhook
        requests = webhook.webhook_requests.order(created_at: :desc).limit(100)

        render_success requests.map { |r|
          {
            uuid: r.uuid,
            event: r.event,
            url: r.url,
            attempts: r.attempts,
            locked_at: r.locked_at&.iso8601,
            retry_after: r.retry_after&.iso8601,
            error: r.error,
            created_at: r.created_at&.iso8601,
          }
        }
      end

      # POST /api/v2/org/:org_permalink/servers/:permalink/webhooks/:uuid/retry/:request_uuid
      def retry_request
        webhook = find_webhook
        request = webhook.webhook_requests.find_by_uuid!(params[:request_uuid])

        request.update!(retry_after: nil, locked_by: nil, locked_at: nil)

        render_success({
          uuid: request.uuid,
          retried: true,
        })
      rescue ActiveRecord::RecordNotFound
        render_not_found("Webhook request not found")
      end

      private

      def find_webhook
        @server.webhooks.find_by_uuid!(params[:uuid])
      rescue ActiveRecord::RecordNotFound
        render_not_found("Webhook not found")
        nil
      end

      def webhook_params
        permitted = params.permit(:name, :url, :all_events, :enabled, :sign, events: [])
        if permitted[:events].present?
          permitted[:events] = permitted[:events]
        end
        permitted
      end

      def require_permission!
        if action_name == "index" || action_name == "show" || action_name == "history"
          require_any_permission!("webhooks.read", "servers.read")
        else
          require_permission!("webhooks.write")
        end
      end

    end
  end
end
