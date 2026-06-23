# frozen_string_literal: true

module API
  module V2
    class UserSerializer < BaseSerializer

      SCHEMA = {
        uuid: :uuid,
        first_name: :first_name,
        last_name: :last_name,
        name: :name,
        email_address: :email_address,
        email_verified: ->(u) { u.email_verified_at.present? },
        admin: :admin,
        time_zone: :time_zone,
        oidc_enabled: ->(u) { u.oidc? },
        organization_count: ->(u) { u.organizations.present.count },
        created_at: ->(u) { u.created_at&.iso8601 },
        updated_at: ->(u) { u.updated_at&.iso8601 },
      }.freeze

      DEFAULT_FIELDS = %i[uuid name email_address email_verified admin time_zone created_at].freeze

      INCLUSIONS = {}.freeze

    end
  end
end
