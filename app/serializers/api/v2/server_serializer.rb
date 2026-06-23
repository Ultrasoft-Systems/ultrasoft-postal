# frozen_string_literal: true

module API
  module V2
    class ServerSerializer < BaseSerializer

      SCHEMA = {
        uuid: :uuid,
        name: :name,
        permalink: :permalink,
        full_permalink: :full_permalink,
        mode: :mode,
        status: :status,
        suspended: ->(s) { s.suspended? },
        suspension_reason: ->(s) { s.actual_suspension_reason },
        send_limit: :send_limit,
        send_limit_approaching: ->(s) { s.send_limit_approaching? },
        send_limit_exceeded: ->(s) { s.send_limit_exceeded? },
        send_volume: ->(s) { s.send_volume },
        queue_size: ->(s) { s.queue_size },
        held_messages: ->(s) { s.held_messages },
        message_rate: ->(s) { s.message_rate&.round(2) },
        bounce_rate: ->(s) { s.bounce_rate&.round(2) },
        spam_threshold: :spam_threshold,
        spam_failure_threshold: :spam_failure_threshold,
        outbound_spam_threshold: :outbound_spam_threshold,
        postmaster_address: :postmaster_address,
        privacy_mode: :privacy_mode,
        allow_sender: :allow_sender,
        log_smtp_data: :log_smtp_data,
        message_retention_days: :message_retention_days,
        raw_message_retention_days: :raw_message_retention_days,
        raw_message_retention_size: :raw_message_retention_size,
        organization_permalink: ->(s) { s.organization&.permalink },
        ip_pool_uuid: ->(s) { s.ip_pool&.uuid },
        token: ->(s, ctx) { ctx[:show_sensitive] ? s.token : nil },
        created_at: ->(s) { s.created_at&.iso8601 },
        updated_at: ->(s) { s.updated_at&.iso8601 },
      }.freeze

      DEFAULT_FIELDS = %i[
        uuid name permalink full_permalink mode status suspended send_limit
        message_rate queue_size created_at
      ].freeze

      INCLUSIONS = {
        domains: { serializer: DomainSerializer },
        credentials: { serializer: CredentialSerializer },
        routes: { serializer: RouteSerializer },
        webhooks: { serializer: WebhookSerializer },
      }.freeze

    end
  end
end
