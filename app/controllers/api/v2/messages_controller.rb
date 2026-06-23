# frozen_string_literal: true

module API
  module V2
    # Messages controller provides read access to incoming, outgoing, and held
    # messages within a server's message database. The server is resolved from
    # the auth scope.
    class MessagesController < BaseController

      before_action :require_server!
      before_action :check_read_permission!

      # GET /api/v2/messages/outgoing
      def outgoing
        messages = @server.message_db.messages(
          where: outgoing_filters,
          order: :timestamp,
          direction: "DESC",
          limit: @per_page,
          offset: (@page - 1) * @per_page,
        )
        total = @server.message_db.messages(count: true, where: outgoing_filters)

        render_message_page(messages, total)
      end

      # GET /api/v2/messages/incoming
      def incoming
        messages = @server.message_db.messages(
          where: incoming_filters,
          order: :timestamp,
          direction: "DESC",
          limit: @per_page,
          offset: (@page - 1) * @per_page,
        )
        total = @server.message_db.messages(count: true, where: incoming_filters)

        render_message_page(messages, total)
      end

      # GET /api/v2/messages/held
      def held
        messages = @server.message_db.messages(
          where: { held: true, **base_filters },
          order: :timestamp,
          direction: "DESC",
          limit: @per_page,
          offset: (@page - 1) * @per_page,
        )
        total = @server.message_db.messages(count: true, where: { held: true, **base_filters })

        render_message_page(messages, total)
      end

      # GET /api/v2/messages/suppressions
      def suppressions
        suppressions = @server.message_db.suppression_list.all
        result = paginate_array(suppressions)
        render_paginated(result[:records], result)
      end

      # GET /api/v2/messages/:id
      def show
        message = find_message
        context = {}
        context[:include_headers] = true if params[:include_headers]
        context[:include_bodies] = true if params[:include_bodies]
        context[:include_raw] = true if params[:include_raw]

        render_success MessageSerializer.serialize(message, context: context)
      end

      # GET /api/v2/messages/:id/deliveries
      def deliveries
        message = find_message
        deliveries = message.deliveries.map do |d|
          {
            id: d.id,
            status: d.status,
            details: d.details,
            output: d.output&.strip,
            sent_with_ssl: d.sent_with_ssl,
            log_id: d.log_id,
            time: d.time&.to_f,
            timestamp: d.timestamp.to_f,
          }
        end
        render_success deliveries
      end

      # GET /api/v2/messages/:id/attachments
      def attachments
        message = find_message
        attachments = message.attachments.map do |att|
          {
            filename: att.filename.to_s,
            content_type: att.mime_type,
            size: att.body.to_s.bytesize,
            hash: Digest::SHA1.hexdigest(att.body.to_s),
          }
        end
        render_success attachments
      end

      # GET /api/v2/messages/:id/attachment/:filename
      def attachment
        message = find_message
        att = message.attachments.find { |a| a.filename == params[:filename] }

        unless att
          render_not_found("Attachment not found")
          return
        end

        send_data att.body.to_s,
                  filename: att.filename,
                  type: att.mime_type,
                  disposition: "attachment"
      end

      # GET /api/v2/messages/:id/plain
      def plain
        message = find_message
        render_success({ body: message.plain_body })
      end

      # GET /api/v2/messages/:id/html
      def html
        message = find_message
        render_success({ body: message.html_body })
      end

      # GET /api/v2/messages/:id/headers
      def headers
        message = find_message
        render_success({ headers: message.headers })
      end

      # GET /api/v2/messages/:id/activity
      def activity
        message = find_message
        render_success({
          loads: message.loads,
          clicks: message.clicks,
        })
      end

      # GET /api/v2/messages/:id/spam_checks
      def spam_checks
        message = find_message
        render_success({
          inspected: message.inspected,
          spam: message.spam,
          spam_score: message.spam_score&.to_f,
          threat: message.threat,
          threat_details: message.threat_details,
        })
      end

      # POST /api/v2/messages/:id/retry
      def retry
        check_manage_permission!

        message = find_message
        queued = QueuedMessage.find_by(message_id: message.id)

        unless queued
          render_error("This message is not queued for delivery", status: :conflict)
          return
        end

        queued.retry_now
        render_success({ retried: true, message_id: message.id })
      end

      # POST /api/v2/messages/:id/cancel_hold
      def cancel_hold
        check_manage_permission!

        message = find_message
        queued = QueuedMessage.find_by(message_id: message.id)

        unless queued
          render_error("This message is not queued", status: :conflict)
          return
        end

        if message.held?
          message.cancel_hold
          render_success({ cancelled: true, message_id: message.id })
        else
          render_error("Message is not on hold", status: :conflict)
        end
      end

      # DELETE /api/v2/messages/:id
      def destroy
        check_manage_permission!

        queued = QueuedMessage.find_by(message_id: params[:id])
        unless queued
          render_not_found("Queued message not found")
          return
        end

        queued.destroy!
        render_destroyed
      end

      private

      def find_message
        @server.message_db.message(params[:id])
      end

      def base_filters
        filters = { scope: action_scope }
        filters[:rcpt_to] = params[:rcpt_to] if params[:rcpt_to].present?
        filters[:mail_from] = params[:mail_from] if params[:mail_from].present?
        filters[:domain_id] = params[:domain_id].to_i if params[:domain_id].present?
        filters[:tag] = params[:tag] if params[:tag].present?
        filters[:credential_id] = params[:credential_id].to_i if params[:credential_id].present?

        if params[:from].present?
          filters[:timestamp] = { greater_than_or_equal_to: Time.parse(params[:from]).to_f }
        end
        if params[:to].present?
          filters[:timestamp] ||= {}
          filters[:timestamp][:less_than_or_equal_to] = Time.parse(params[:to]).to_f
        end

        filters
      end

      def outgoing_filters
        base_filters.merge(scope: "outgoing")
      end

      def incoming_filters
        base_filters.merge(scope: "incoming")
      end

      def action_scope
        case action_name
        when "outgoing" then "outgoing"
        when "incoming" then "incoming"
        end
      end

      def render_message_page(messages, total)
        total_pages, remainder = total.to_i.divmod(@per_page)
        total_pages += 1 if remainder.positive?

        serialized = messages.map { |m| MessageSerializer.serialize(m) }
        render_paginated(serialized, {
          page: @page,
          per_page: @per_page,
          total: total.to_i,
          total_pages: total_pages,
        })
      end

      def check_read_permission!
        if action_name.in?(%w[retry cancel_hold destroy])
          # checked separately in each action
          require_any_permission!("messages.read", "messages.send")
        else
          require_any_permission!("messages.read", "messages.send")
        end
      end

      def check_manage_permission!
        require_permission!("messages.manage")
      end

    end
  end
end
