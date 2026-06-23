# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v2 Pagination", type: :request do
  let(:user) { create(:user, admin: true) }
  let(:organization) { create(:organization, owner: user) }
  let(:token) { create(:api_token, organization: organization, scope: "organization", permissions: %w[organizations.read]) }
  let(:headers) { { "X-Postal-API-Key": token.token } }

  before do
    create_list(:server, 5, organization: organization)
  end

  it "paginates results with default page size" do
    get "/api/v2/org/#{organization.permalink}/servers", headers: headers

    json = JSON.parse(response.body)
    expect(json["meta"]["per_page"]).to eq(30)
    expect(json["meta"]["page"]).to eq(1)
    expect(json["meta"]["total"]).to eq(5)
    expect(json["meta"]["total_pages"]).to eq(1)
  end

  it "respects per_page parameter" do
    get "/api/v2/org/#{organization.permalink}/servers?per_page=2", headers: headers

    json = JSON.parse(response.body)
    expect(json["meta"]["per_page"]).to eq(2)
    expect(json["data"].size).to be <= 2
  end

  it "respects page parameter" do
    get "/api/v2/org/#{organization.permalink}/servers?per_page=2&page=2", headers: headers

    json = JSON.parse(response.body)
    expect(json["meta"]["page"]).to eq(2)
  end

  it "caps per_page at 200" do
    get "/api/v2/org/#{organization.permalink}/servers?per_page=500", headers: headers

    json = JSON.parse(response.body)
    expect(json["meta"]["per_page"]).to eq(200)
  end
end
