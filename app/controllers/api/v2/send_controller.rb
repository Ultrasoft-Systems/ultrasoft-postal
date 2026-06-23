# frozen_string_literal: true

module API
  module V2
    # Send controller provides the v2 equivalent of the legacy send API endpoints.
    # Both structured message sending and raw RFC2822 sending are supported.
    class SendController < BaseController

      before_action :check_send_permission!

      # POST /api/v2/send/message
      #
      # Parameters:  to (array, required), cc (array), bcc (array),
      #              from (string, required), sender (string),
      #              subject (string), reply_to (string),
      #              plain_body (string), html_body (string),
      #              tag (string), bounce (boolean),
      #              headers (object), attachments (array of {name, content_type, data})
      #
      # Response:    { message_id, messages: { "<address>": { id, token } } }
      def message
        attributes = build_message_attributes

        prototype = OutgoingMessagePrototype.new(@current_server, request.ip, "api", attributes)
        prototype.credential = @current_credential

        if prototype.valid?
          result = prototype.create_messages
          render_success({
            message_id: prototype.message_id,
            messages: result,
          })
        else
          render_error(
            ERROR_MESSAGES[prototype.errors.first] || prototype.errors.first,
            code: prototype.errors.first,
            details: { errors: prototype.errors },
          )
        end
      end

      # POST /api/v2/send/raw
      #
      # Parameters:  rcpt_to (array, required), mail_from (string, required),
      #              data (string, required — base64-encoded RFC2822 message),
      #              bounce (boolean)
      #
      # Response:    { message_id, messages: { "<address>": { id, token } } }
      def raw
        unless params[:rcpt_to].is_a?(Array)
          render_error("`rcpt_to` parameter is required and must be an array", code: "MISSING_RCPT_TO")
          return
        end

        if params[:mail_from].blank?
          render_error("`mail_from` parameter is required", code: "MISSING_MAIL_FROM")
          return
        end

        if params[:data].blank?
          render_error("`data` parameter is required (base64-encoded RFC2822 message)", code: "MISSING_DATA")
          return
        end

        raw_message = begin
          Base64.decode64(params[:data])
        rescue StandardError
          render_error("`data` parameter is not valid base64", code: "INVALID_BASE64")
          return
        end

        # Parse headers to find the authenticated domain
        mail = Mail.new(raw_message.split("\r\n\r\n", 2).first)
        from_headers = { "from" => mail.from, "sender" => mail.sender }
        authenticated_domain = @current_server.find_authenticated_domain_from_headers(from_headers)

        if authenticated_domain.nil?
          render_error(
            "The from address is not authorised to send mail from this server",
            code: "UnauthenticatedFromAddress",
          )
          return
        end

        result = { message_id: nil, messages: {} }
        params[:rcpt_to].uniq.each do |rcpt_to|
          message = @current_server.message_db.new_message
          message.rcpt_to = rcpt_to
          message.mail_from = params[:mail_from]
          message.raw_message = raw_message
          message.received_with_ssl = true
          message.scope = "outgoing"
          message.domain_id = authenticated_domain.id
          message.credential_id = @current_credential&.id
          message.bounce = params[:bounce] ? true : false
          message.save

          result[:message_id] = message.message_id if result[:message_id].nil?
          result[:messages][rcpt_to] = { id: message.id, token: message.token }
        end

        render_success(result)
      end

      private

      ERROR_MESSAGES = {
        "NoRecipients" => "There are no recipients defined to receive this message",
        "NoContent" => "There is no content defined for this e-mail",
        "TooManyToAddresses" => "The maximum number of To addresses has been reached (maximum 50)",
        "TooManyCCAddresses" => "The maximum number of CC addresses has been reached (maximum 50)",
        "TooManyBCCAddresses" => "The maximum number of BCC addresses has been reached (maximum 50)",
        "FromAddressMissing" => "The From address is missing and is required",
        "UnauthenticatedFromAddress" => "The From address is not authorised to send mail from this server",
        "AttachmentMissingName" => "An attachment is missing a name",
        "AttachmentMissingData" => "An attachment is missing data",
      }.freeze

      def build_message_attributes
        attrs = {}
        attrs[:to] = params[:to]
        attrs[:cc] = params[:cc]
        attrs[:bcc] = params[:bcc]
        attrs[:from] = params[:from]
        attrs[:sender] = params[:sender]
        attrs[:subject] = params[:subject]
        attrs[:reply_to] = params[:reply_to]
        attrs[:plain_body] = params[:plain_body]
        attrs[:html_body] = params[:html_body]
        attrs[:bounce] = params[:bounce] ? true : false
        attrs[:tag] = params[:tag]
        attrs[:custom_headers] = params[:headers] if params[:headers]
        attrs[:attachments] = (params[:attachments] || []).map do |att|
          next unless att.is_a?(Hash) || att.is_a?(ActionController::Parameters)

          {
            name: att[:name] || att["name"],
            content_type: att[:content_type] || att["content_type"],
            data: att[:data] || att["data"],
            base64: true,
          }
        end.compact
        attrs
      end

      def check_send_permission!
        require_permission!("messages.send")
      end

    end
  end
end
