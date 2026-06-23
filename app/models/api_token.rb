# frozen_string_literal: true

# == Schema Information
#
# Table name: api_tokens
#
#  id              :integer          not null, primary key
#  token           :string(255)      not null
#  name            :string(255)      not null
#  scope           :string(255)      not null, default("server")
#  permissions     :text(65535)
#  user_id         :integer
#  organization_id :integer
#  server_id       :integer
#  last_used_at    :datetime
#  expires_at      :datetime
#  revoked_at      :datetime
#  uuid            :string(255)
#  created_at      :datetime
#  updated_at      :datetime
#
# Indexes
#
#  index_api_tokens_on_token           (token) UNIQUE
#  index_api_tokens_on_uuid            (uuid) UNIQUE
#  index_api_tokens_on_user_id         (user_id)
#  index_api_tokens_on_organization_id (organization_id)
#  index_api_tokens_on_server_id       (server_id)
#

class APIToken < ApplicationRecord

  SCOPES = %w[user organization server].freeze

  include HasUUID

  belongs_to :user, optional: true
  belongs_to :organization, optional: true
  belongs_to :server, optional: true

  validates :token, presence: true, uniqueness: { case_sensitive: true }
  validates :name, presence: true
  validates :scope, inclusion: { in: SCOPES }
  validate :validate_single_scope_target
  validate :validate_appropriate_scope_target

  serialize :permissions, type: Array

  before_validation :generate_token, on: :create
  before_validation :set_default_permissions, on: :create

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :not_expired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at > Time.current)
  end

  def use
    touch(:last_used_at) if persisted?
  end

  def revoke
    update!(revoked_at: Time.current)
  end

  def has_permission?(key)
    return true if permissions.include?("*")
    permissions.include?(key)
  end

  def to_param
    uuid
  end

  private

  def generate_token
    self.token = "pstl_#{SecureRandom.hex(24)}"
  end

  def set_default_permissions
    self.permissions ||= case scope
                         when "server"
                           %w[messages.read messages.send]
                         when "organization"
                           %w[organizations.read servers.read domains.read credentials.read routes.read endpoints.read webhooks.read messages.read messages.send stats.read]
                         when "user"
                           %w[organizations.read servers.read domains.read credentials.read routes.read endpoints.read webhooks.read messages.read messages.send suppressions.read stats.read]
                         end
  end

  def validate_single_scope_target
    targets = [user_id, organization_id, server_id].compact
    return unless targets.size > 1

    errors.add :base, "An API token can only be scoped to one target (user, organization, or server)"
  end

  def validate_appropriate_scope_target
    case scope
    when "user"
      errors.add(:user_id, "must be set for user-scoped tokens") unless user_id
    when "organization"
      errors.add(:organization_id, "must be set for organization-scoped tokens") unless organization_id
    when "server"
      errors.add(:server_id, "must be set for server-scoped tokens") unless server_id
    end
  end

  class << self

    def find_by_token(token)
      return nil if token.blank?

      active.not_expired.find_by(token: token)
    end

  end

end
