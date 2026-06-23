# frozen_string_literal: true

module API
  module V2
    class RouteSerializer < BaseSerializer

      SCHEMA = {
        uuid: :uuid,
        name: :name,
        description: :description,
        mode: :mode,
        spam_mode: :spam_mode,
        endpoint: :_endpoint,
        endpoint_type: :endpoint_type,
        domain_name: ->(r) { r.domain&.name },
        return_path: ->(r) { r.return_path? },
        wildcard: ->(r) { r.wildcard? },
        forward_address: :forward_address,
        additional_endpoints: ->(r) { r.additional_route_endpoints_array },
        server_permalink: ->(r) { r.server&.permalink },
        created_at: ->(r) { r.created_at&.iso8601 },
        updated_at: ->(r) { r.updated_at&.iso8601 },
      }.freeze

      DEFAULT_FIELDS = %i[uuid name description mode spam_mode endpoint domain_name created_at].freeze

      INCLUSIONS = {}.freeze

    end
  end
end
