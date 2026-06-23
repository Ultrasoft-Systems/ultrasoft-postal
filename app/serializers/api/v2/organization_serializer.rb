# frozen_string_literal: true

module API
  module V2
    class OrganizationSerializer < BaseSerializer

      SCHEMA = {
        uuid: :uuid,
        name: :name,
        permalink: :permalink,
        time_zone: :time_zone,
        status: :status,
        suspended: ->(o) { o.suspended? },
        owner_email: ->(o) { o.owner&.email_address },
        server_count: ->(o) { o.servers.present.count },
        created_at: ->(o) { o.created_at&.iso8601 },
        updated_at: ->(o) { o.updated_at&.iso8601 },
      }.freeze

      DEFAULT_FIELDS = %i[uuid name permalink time_zone status suspended server_count created_at].freeze

      INCLUSIONS = {
        servers: { serializer: ServerSerializer },
      }.freeze

    end
  end
end
