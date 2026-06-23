# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v2 Authentication", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:user) { create(:user) }

  describe "token-based authentication" do
    it "rejects requests without an API key" do
      get "/api/v2/organizations"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["code"]).to eq("UNAUTHORIZED")
    end

    it "rejects requests with an invalid token" do
      get "/api/v2/organizations", headers: { "X-Postal-API-Key": "invalid-token" }

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
    end

    it "rejects requests with an expired token" do
      token = create(:api_token, server: server, expires_at: 1.day.ago)

      get "/api/v2/organizations", headers: { "X-Postal-API-Key": token.token }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects requests with a revoked token" do
      token = create(:api_token, server: server, revoked_at: Time.current)

      get "/api/v2/organizations", headers: { "X-Postal-API-Key": token.token }

      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts requests with a valid API token" do
      token = create(:api_token, organization: organization, scope: "organization")

      get "/api/v2/organizations", headers: { "X-Postal-API-Key": token.token }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end

    it "updates last_used_at on successful authentication" do
      token = create(:api_token, organization: organization, scope: "organization")

      expect {
        get "/api/v2/organizations", headers: { "X-Postal-API-Key": token.token }
      }.to change { token.reload.last_used_at }.from(nil)
    end
  end

  describe "legacy credential authentication" do
    let(:credential) { create(:credential, server: server, type: "API") }

    it "accepts requests with X-Server-API-Key header" do
      get "/api/v2/organizations", headers: { "X-Server-API-Key": credential.key }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end

    it "rejects suspended server credentials" do
      credential
      server.suspend("Test suspension")

      get "/api/v2/organizations", headers: { "X-Server-API-Key": credential.key }

      expect(response).to have_http_status(:forbidden)
    end

    it "records credential usage" do
      expect {
        get "/api/v2/organizations", headers: { "X-Server-API-Key": credential.key }
      }.to change { credential.reload.last_used_at }.from(nil)
    end
  end

  describe "permission enforcement" do
    let(:token) { create(:api_token, server: server, permissions: %w[messages.read messages.send]) }

    it "allows actions with matching permission" do
      # This test sends a request to an endpoint the token has permission for
      post "/api/v2/send/message",
           headers: { "X-Postal-API-Key": token.token, "Content-Type": "application/json" },
           params: { to: ["test@example.com"], from: "sender@example.com", subject: "Test", plain_body: "Hello" }.to_json

      # Either succeeds or fails on validation (not auth)
      expect(response).not_to have_http_status(:forbidden)
      expect(response).not_to have_http_status(:unauthorized)
    end

    it "blocks actions without matching permission" do
      patch "/api/v2/organizations/nonexistent",
            headers: { "X-Postal-API-Key": token.token, "Content-Type": "application/json" },
            params: { name: "New Name" }.to_json

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["code"]).to eq("FORBIDDEN")
    end
  end

  describe "response envelope" do
    let(:token) { create(:api_token, organization: organization, scope: "organization") }

    it "returns consistent success envelope" do
      get "/api/v2/organizations", headers: { "X-Postal-API-Key": token.token }

      json = JSON.parse(response.body)
      expect(json).to have_key("success")
      expect(json["success"]).to be true
      expect(json).to have_key("data")
      expect(json).to have_key("meta")
    end

    it "returns consistent error envelope" do
      get "/api/v2/organizations/nonexistent", headers: { "X-Postal-API-Key": token.token }

      json = JSON.parse(response.body)
      expect(json).to have_key("success")
      expect(json["success"]).to be false
      expect(json).to have_key("error")
      expect(json).to have_key("code")
    end

    it "sets Content-Type to application/json" do
      get "/api/v2/organizations", headers: { "X-Postal-API-Key": token.token }

      expect(response.content_type).to include("application/json")
    end
  end

  describe "rate limit headers" do
    let(:token) { create(:api_token, organization: organization, scope: "organization") }

    it "includes rate limit headers in response" do
      get "/api/v2/organizations", headers: { "X-Postal-API-Key": token.token }

      expect(response.headers).to have_key("X-RateLimit-Limit")
      expect(response.headers).to have_key("X-RateLimit-Remaining")
      expect(response.headers).to have_key("X-RateLimit-Reset")
    end
  end
end
