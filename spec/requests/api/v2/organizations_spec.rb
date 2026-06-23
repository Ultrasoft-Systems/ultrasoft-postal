# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v2 Organizations", type: :request do
  let(:user) { create(:user, admin: true) }
  let(:token) { create(:api_token, user: user, scope: "user", permissions: %w[organizations.read organizations.write]) }
  let(:headers) { { "X-Postal-API-Key": token.token, "Content-Type": "application/json" } }

  describe "GET /api/v2/organizations" do
    let!(:org1) { create(:organization, name: "Alpha", owner: user) }
    let!(:org2) { create(:organization, name: "Beta", owner: user) }

    it "returns a paginated list of organizations" do
      get "/api/v2/organizations", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["data"]).to be_an(Array)
      expect(json["meta"]).to include("page", "per_page", "total")
    end

    it "includes organization attributes" do
      get "/api/v2/organizations", headers: headers

      json = JSON.parse(response.body)
      org_data = json["data"].find { |o| o["permalink"] == org1.permalink }
      expect(org_data).to be_present
      expect(org_data["name"]).to eq("Alpha")
      expect(org_data["uuid"]).to be_present
    end
  end

  describe "GET /api/v2/organizations/:permalink" do
    let!(:org) { create(:organization, name: "MyOrg", owner: user) }

    it "returns organization details" do
      get "/api/v2/organizations/#{org.permalink}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["name"]).to eq("MyOrg")
      expect(json["data"]["permalink"]).to eq(org.permalink)
    end

    it "returns 404 for non-existent organization" do
      get "/api/v2/organizations/nonexistent", headers: headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["code"]).to eq("NOT_FOUND")
    end
  end

  describe "POST /api/v2/organizations" do
    it "creates a new organization" do
      post "/api/v2/organizations",
           headers: headers,
           params: { name: "NewOrg", time_zone: "UTC" }.to_json

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["name"]).to eq("NewOrg")
      expect(json["data"]["permalink"]).to eq("neworg")
    end

    it "returns validation errors for invalid data" do
      post "/api/v2/organizations",
           headers: headers,
           params: { name: "" }.to_json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["code"]).to eq("VALIDATION_ERROR")
    end
  end

  describe "PATCH /api/v2/organizations/:permalink" do
    let!(:org) { create(:organization, name: "OldName", owner: user) }

    it "updates an organization" do
      patch "/api/v2/organizations/#{org.permalink}",
            headers: headers,
            params: { name: "NewName" }.to_json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["name"]).to eq("NewName")
    end
  end

  describe "DELETE /api/v2/organizations/:permalink" do
    let!(:org) { create(:organization, name: "ToDelete", owner: user) }

    it "soft-deletes the organization" do
      delete "/api/v2/organizations/#{org.permalink}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["deleted"]).to be true
      expect(org.reload.deleted_at).to be_present
    end
  end
end
