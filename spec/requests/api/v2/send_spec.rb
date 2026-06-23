# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v2 Send", type: :request do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }
  let(:domain) { create(:domain, owner: server, name: "example.com", verified_at: Time.current) }
  let(:token) { create(:api_token, server: server, scope: "server", permissions: %w[messages.send messages.read]) }
  let(:headers) { { "X-Postal-API-Key": token.token, "Content-Type": "application/json" } }

  describe "POST /api/v2/send/message" do
    before { domain }

    it "sends a message with valid parameters" do
      post "/api/v2/send/message",
           headers: headers,
           params: {
             to: ["recipient@example.com"],
             from: "sender@example.com",
             subject: "Test Subject",
             plain_body: "Hello, this is a test email.",
           }.to_json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["data"]).to have_key("message_id")
      expect(json["data"]).to have_key("messages")
    end

    it "returns error when no recipients provided" do
      post "/api/v2/send/message",
           headers: headers,
           params: {
             from: "sender@example.com",
             subject: "Test",
             plain_body: "Hello",
           }.to_json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
    end

    it "returns error when no content provided" do
      post "/api/v2/send/message",
           headers: headers,
           params: {
             to: ["recipient@example.com"],
             from: "sender@example.com",
             subject: "Test",
           }.to_json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["code"]).to eq("NoContent")
    end

    it "returns error when from address is unauthenticated" do
      post "/api/v2/send/message",
           headers: headers,
           params: {
             to: ["recipient@example.com"],
             from: "unknown@otherdomain.com",
             subject: "Test",
             plain_body: "Hello",
           }.to_json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["code"]).to eq("UnauthenticatedFromAddress")
    end

    it "requires messages.send permission" do
      restricted_token = create(:api_token, server: server, permissions: %w[messages.read])
      post "/api/v2/send/message",
           headers: { "X-Postal-API-Key": restricted_token.token, "Content-Type": "application/json" },
           params: { to: ["test@example.com"], from: "sender@example.com", subject: "Test", plain_body: "Hi" }.to_json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v2/send/raw" do
    before { domain }

    let(:raw_email) do
      mail = Mail.new do
        from    "sender@example.com"
        to      "recipient@example.com"
        subject "Raw Test"
        body    "This is a raw email."
      end
      Base64.encode64(mail.to_s)
    end

    it "sends a raw message with valid parameters" do
      post "/api/v2/send/raw",
           headers: headers,
           params: {
             rcpt_to: ["recipient@example.com"],
             mail_from: "sender@example.com",
             data: raw_email,
           }.to_json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["data"]).to have_key("messages")
    end

    it "returns error when rcpt_to is missing" do
      post "/api/v2/send/raw",
           headers: headers,
           params: {
             mail_from: "sender@example.com",
             data: raw_email,
           }.to_json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["code"]).to eq("MISSING_RCPT_TO")
    end

    it "returns error when mail_from is missing" do
      post "/api/v2/send/raw",
           headers: headers,
           params: {
             rcpt_to: ["recipient@example.com"],
             data: raw_email,
           }.to_json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["code"]).to eq("MISSING_MAIL_FROM")
    end

    it "returns error when data is missing" do
      post "/api/v2/send/raw",
           headers: headers,
           params: {
             rcpt_to: ["recipient@example.com"],
             mail_from: "sender@example.com",
           }.to_json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["code"]).to eq("MISSING_DATA")
    end

    it "returns error when data is not valid base64" do
      post "/api/v2/send/raw",
           headers: headers,
           params: {
             rcpt_to: ["recipient@example.com"],
             mail_from: "sender@example.com",
             data: "!!!not valid base64!!!",
           }.to_json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["code"]).to eq("INVALID_BASE64")
    end
  end
end
