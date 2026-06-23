# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v2 Servers", type: :request do
  let(:user) { create(:user, admin: true) }
  let(:organization) { create(:organization, owner: user) }
  let(:token) { create(:api_token, organization: organization, scope: "organization", permissions: %w[servers.read servers.write servers.suspend]) }
  let(:headers) { { "X-Postal-API-Key": token.token, "Content-Type": "application/json" } }

  describe "GET /api/v2/org/:org_permalink/servers" do
    let!(:server1) { create(:server, organization: organization, name: "Server One") }
    let!(:server2) { create(:server, organization: organization, name: "Server Two") }

    it "returns paginated list of servers" do
      get "/api/v2/org/#{organization.permalink}/servers", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["meta"]).to include("page", "per_page", "total")
      expect(json["data"].size).to eq(2)
    end
  end

  describe "GET /api/v2/org/:org_permalink/servers/:permalink" do
    let!(:server) { create(:server, organization: organization, name: "MailServer") }

    it "returns server details" do
      get "/api/v2/org/#{organization.permalink}/servers/#{server.permalink}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["name"]).to eq("MailServer")
      expect(json["data"]["permalink"]).to eq(server.permalink)
      expect(json["data"]["mode"]).to be_present
    end

    it "returns 404 for non-existent server" do
      get "/api/v2/org/#{organization.permalink}/servers/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v2/org/:org_permalink/servers" do
    it "creates a new server" do
      post "/api/v2/org/#{organization.permalink}/servers",
           headers: headers,
           params: { name: "NewServer", mode: "Live" }.to_json

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["name"]).to eq("NewServer")
    end

    it "returns validation errors" do
      post "/api/v2/org/#{organization.permalink}/servers",
           headers: headers,
           params: { name: "" }.to_json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v2/org/:org_permalink/servers/:permalink" do
    let!(:server) { create(:server, organization: organization, name: "OldName") }

    it "updates a server" do
      patch "/api/v2/org/#{organization.permalink}/servers/#{server.permalink}",
            headers: headers,
            params: { name: "NewName" }.to_json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["name"]).to eq("NewName")
    end
  end

  describe "POST /api/v2/org/:org_permalink/servers/:permalink/suspend" do
    let!(:server) { create(:server, organization: organization) }

    it "suspends the server" do
      post "/api/v2/org/#{organization.permalink}/servers/#{server.permalink}/suspend",
           headers: headers,
           params: { reason: "Testing suspension" }.to_json

      expect(response).to have_http_status(:ok)
      expect(server.reload.suspended?).to be true
    end
  end

  describe "POST /api/v2/org/:org_permalink/servers/:permalink/unsuspend" do
    let!(:server) { create(:server, organization: organization, suspended_at: Time.current, suspension_reason: "Test") }

    it "unsuspends the server" do
      post "/api/v2/org/#{organization.permalink}/servers/#{server.permalink}/unsuspend",
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(server.reload.suspended?).to be false
    end
  end

  describe "GET /api/v2/org/:org_permalink/servers/:permalink/stats" do
    let!(:server) { create(:server, organization: organization) }

    it "returns server statistics" do
      get "/api/v2/org/#{organization.permalink}/servers/#{server.permalink}/stats",
          headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to have_key("throughput")
      expect(json["data"]).to have_key("message_rate")
      expect(json["data"]).to have_key("bounce_rate")
    end
  end

  describe "GET /api/v2/org/:org_permalink/servers/:permalink/queue" do
    let!(:server) { create(:server, organization: organization) }

    it "returns queue information" do
      get "/api/v2/org/#{organization.permalink}/servers/#{server.permalink}/queue",
          headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to have_key("queue_size")
      expect(json["data"]).to have_key("held_messages")
    end
  end

  describe "GET /api/v2/org/:org_permalink/servers/:permalink/limits" do
    let!(:server) { create(:server, organization: organization, send_limit: 100) }

    it "returns send limit information" do
      get "/api/v2/org/#{organization.permalink}/servers/#{server.permalink}/limits",
          headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["send_limit"]).to eq(100)
      expect(json["data"]).to have_key("usage_percent")
    end
  end

  describe "DELETE /api/v2/org/:org_permalink/servers/:permalink" do
    let!(:server) { create(:server, organization: organization) }

    it "soft-deletes the server" do
      delete "/api/v2/org/#{organization.permalink}/servers/#{server.permalink}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(server.reload.deleted_at).to be_present
    end
  end
end
