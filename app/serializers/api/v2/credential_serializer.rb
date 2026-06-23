# frozen_string_literal: true

module API
  module V2
    class CredentialSerializer < BaseSerializer

      SCHEMA = {
        uuid: :uuid,
        name: :name,
        type: :type,
        key: ->(c, ctx) { ctx[:show_sensitive] ? c.key : mask_key(c.key) },
        hold: :hold,
        usage_type: :usage_type,
        last_used_at: ->(c) { c.last_used_at&.iso8601 },
        server_permalink: ->(c) { c.server&.permalink },
        created_at: ->(c) { c.created_at&.iso8601 },
        updated_at: ->(c) { c.updated_at&.iso8601 },
      }.freeze

      DEFAULT_FIELDS = %i[uuid name type key hold usage_type last_used_at created_at].freeze

      INCLUSIONS = {}.freeze

      class << self

        def mask_key(key)
          return nil if key.nil?

          if key.length <= 4
            "*" * key.length
          else
            key[0, 4] + "*" * (key.length - 4)
          end
        end

      end

    end
  end
end
