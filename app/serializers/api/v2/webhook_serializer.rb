# frozen_string_literal: true

module API
  module V2
    class WebhookSerializer < BaseSerializer

      SCHEMA = {
        uuid: :uuid,
        name: :name,
        url: :url,
        enabled: :enabled,
        all_events: :all_events,
        sign: :sign,
        events: :events,
        last_used_at: ->(w) { w.last_used_at&.iso8601 },
        server_permalink: ->(w) { w.server&.permalink },
        created_at: ->(w) { w.created_at&.iso8601 },
        updated_at: ->(w) { w.updated_at&.iso8601 },
      }.freeze

      DEFAULT_FIELDS = %i[uuid name url enabled all_events events last_used_at created_at].freeze

      INCLUSIONS = {}.freeze

    end
  end
end
