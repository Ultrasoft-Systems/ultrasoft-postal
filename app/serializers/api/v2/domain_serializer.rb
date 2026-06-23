# frozen_string_literal: true

module API
  module V2
    class DomainSerializer < BaseSerializer

      SCHEMA = {
        uuid: :uuid,
        name: :name,
        verified: ->(d) { d.verified? },
        verified_at: ->(d) { d.verified_at&.iso8601 },
        verification_method: :verification_method,
        outgoing: :outgoing,
        incoming: :incoming,
        use_for_any: :use_for_any,
        owner_type: :owner_type,
        spf_status: :spf_status,
        spf_error: :spf_error,
        dkim_status: :dkim_status,
        dkim_error: :dkim_error,
        mx_status: :mx_status,
        mx_error: :mx_error,
        return_path_status: :return_path_status,
        return_path_error: :return_path_error,
        dkim_identifier: :dkim_identifier,
        dkim_record: :dkim_record,
        dkim_record_name: :dkim_record_name,
        spf_record: :spf_record,
        dns_checked_at: ->(d) { d.dns_checked_at&.iso8601 },
        return_path_domain: :return_path_domain,
        created_at: ->(d) { d.created_at&.iso8601 },
        updated_at: ->(d) { d.updated_at&.iso8601 },
      }.freeze

      DEFAULT_FIELDS = %i[
        uuid name verified verification_method outgoing incoming
        spf_status dkim_status mx_status return_path_status
        spf_record dkim_record dkim_record_name dkim_identifier
        return_path_domain dns_checked_at created_at
      ].freeze

      INCLUSIONS = {}.freeze

    end
  end
end
