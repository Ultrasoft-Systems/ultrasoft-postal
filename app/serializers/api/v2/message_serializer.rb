# frozen_string_literal: true

module API
  module V2
    class MessageSerializer < BaseSerializer

      SCHEMA = {
        id: :id,
        token: :token,
        scope: :scope,
        status: :status,
        rcpt_to: :rcpt_to,
        mail_from: :mail_from,
        subject: :subject,
        message_id: :message_id,
        size: :size,
        bounce: :bounce,
        bounce_for_id: :bounce_for_id,
        tag: :tag,
        held: :held,
        hold_expiry: ->(m) { m.hold_expiry&.to_f },
        spam: :spam,
        spam_score: ->(m) { m.spam_score&.to_f },
        threat: :threat,
        threat_details: :threat_details,
        inspected: :inspected,
        received_with_ssl: :received_with_ssl,
        timestamp: ->(m) { m.timestamp&.to_f },
        raw_message_size: ->(m) { m.raw_message&.bytesize },
        has_plain_body: ->(m) { m.plain_body.present? },
        has_html_body: ->(m) { m.html_body.present? },
        has_attachments: ->(m) { m.attachments&.any? },
        attachment_count: ->(m) { m.attachments&.size || 0 },
        domain_name: ->(m) { m.domain&.name },
        credential_name: ->(m) { m.credential&.name },
        route_description: ->(m) { m.route&.description },
        endpoint_type: :endpoint_type,
        endpoint_id: :endpoint_id,
        last_delivery_attempt: ->(m) { m.last_delivery_attempt&.to_f },
        headers: ->(m, ctx) { ctx[:include_headers] ? m.headers : nil },
        plain_body: ->(m, ctx) { ctx[:include_bodies] ? m.plain_body : nil },
        html_body: ->(m, ctx) { ctx[:include_bodies] ? m.html_body : nil },
        raw_message: ->(m, ctx) { ctx[:include_raw] ? Base64.encode64(m.raw_message.to_s) : nil },
      }.freeze

      DEFAULT_FIELDS = %i[
        id token scope status rcpt_to mail_from subject size bounce tag
        spam threat inspected timestamp created_at
      ].freeze

      INCLUSIONS = {}.freeze

      def self.serialize(message, include: nil, fields: nil, context: {})
        result = super
        # Add computed timestamp field
        result[:created_at] = message.timestamp&.to_f if result.key?(:created_at)
        result
      end

    end
  end
end
