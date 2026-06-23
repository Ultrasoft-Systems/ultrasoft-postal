# frozen_string_literal: true

require "rails_helper"

RSpec.describe APIToken, type: :model do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:user) { create(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "generates a token on creation" do
      token = create(:api_token, server: server)
      expect(token.token).to start_with("pstl_")
      expect(token.token.length).to be > 40
    end

    it "validates scope inclusion" do
      token = build(:api_token, server: server, scope: "invalid")
      expect(token).not_to be_valid
      expect(token.errors[:scope]).to be_present
    end

    it "requires exactly one scope target" do
      token = build(:api_token, server: server, user: user)
      expect(token).not_to be_valid
      expect(token.errors[:base]).to include(/can only be scoped to one target/)
    end

    it "requires user for user-scoped tokens" do
      token = build(:api_token, scope: "user", user: nil)
      expect(token).not_to be_valid
      expect(token.errors[:user_id]).to be_present
    end

    it "requires organization for organization-scoped tokens" do
      token = build(:api_token, scope: "organization", organization: nil)
      expect(token).not_to be_valid
      expect(token.errors[:organization_id]).to be_present
    end

    it "requires server for server-scoped tokens" do
      token = build(:api_token, scope: "server", server: nil)
      expect(token).not_to be_valid
      expect(token.errors[:server_id]).to be_present
    end
  end

  describe "scopes" do
    let!(:active_token) { create(:api_token, server: server) }
    let!(:expired_token) { create(:api_token, server: server, expires_at: 1.day.ago) }
    let!(:revoked_token) { create(:api_token, server: server, revoked_at: Time.current) }

    it ".active returns non-revoked, non-expired tokens" do
      expect(described_class.active).to include(active_token)
      expect(described_class.active).not_to include(expired_token)
      expect(described_class.active).not_to include(revoked_token)
    end

    it ".not_expired returns non-expired tokens" do
      expect(described_class.not_expired).to include(active_token, revoked_token)
      expect(described_class.not_expired).not_to include(expired_token)
    end

    it ".find_by_token finds active non-expired tokens" do
      expect(described_class.find_by_token(active_token.token)).to eq(active_token)
      expect(described_class.find_by_token(expired_token.token)).to be_nil
      expect(described_class.find_by_token(revoked_token.token)).to be_nil
      expect(described_class.find_by_token("")).to be_nil
      expect(described_class.find_by_token(nil)).to be_nil
    end
  end

  describe "#active?" do
    it "returns true for active tokens" do
      token = create(:api_token, server: server)
      expect(token.active?).to be true
    end

    it "returns false for expired tokens" do
      token = create(:api_token, server: server, expires_at: 1.day.ago)
      expect(token.active?).to be false
    end

    it "returns false for revoked tokens" do
      token = create(:api_token, server: server, revoked_at: Time.current)
      expect(token.active?).to be false
    end
  end

  describe "#has_permission?" do
    it "returns true if token has the specific permission" do
      token = create(:api_token, server: server, permissions: %w[messages.read messages.send])
      expect(token.has_permission?("messages.read")).to be true
      expect(token.has_permission?("messages.send")).to be true
    end

    it "returns false if token lacks the permission" do
      token = create(:api_token, server: server, permissions: %w[messages.read])
      expect(token.has_permission?("servers.write")).to be false
    end

    it "returns true for all permissions if token has wildcard" do
      token = create(:api_token, server: server, permissions: %w[*])
      expect(token.has_permission?("anything.at.all")).to be true
    end
  end

  describe "#use" do
    it "updates last_used_at" do
      token = create(:api_token, server: server)
      expect { token.use }.to change { token.reload.last_used_at }.from(nil)
    end
  end

  describe "#revoke" do
    it "sets revoked_at" do
      token = create(:api_token, server: server)
      token.revoke
      expect(token.reload.revoked_at).to be_present
      expect(token.active?).to be false
    end
  end

  describe "#to_param" do
    it "returns the uuid" do
      token = create(:api_token, server: server)
      expect(token.to_param).to eq(token.uuid)
    end
  end

  describe "default permissions" do
    it "sets server-scoped defaults" do
      token = create(:api_token, server: server)
      expect(token.permissions).to include("messages.read", "messages.send")
    end

    it "sets organization-scoped defaults" do
      token = create(:api_token, organization: organization, scope: "organization")
      expect(token.permissions).to include("organizations.read", "servers.read", "messages.send")
    end

    it "sets user-scoped defaults" do
      token = create(:api_token, user: user, scope: "user")
      expect(token.permissions).to include("organizations.read", "servers.read", "suppressions.read")
    end
  end
end
