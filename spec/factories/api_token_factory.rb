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
FactoryBot.define do
  factory :api_token do
    name { "Example API Token" }
    scope { "server" }
    permissions { %w[messages.read messages.send] }
    association :server
  end
end
