# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::V2::BaseSerializer do
  let(:organization) { create(:organization) }
  let(:server) { create(:server, organization: organization) }

  describe ".serialize" do
    it "returns nil for nil object" do
      expect(API::V2::OrganizationSerializer.serialize(nil)).to be_nil
    end

    it "returns a hash with default fields" do
      result = API::V2::OrganizationSerializer.serialize(organization)
      expect(result).to be_a(Hash)
      expect(result).to have_key(:uuid)
      expect(result).to have_key(:name)
      expect(result).to have_key(:permalink)
      expect(result).to have_key(:created_at)
    end

    it "respects custom field selection" do
      result = API::V2::OrganizationSerializer.serialize(organization, fields: [:uuid, :name])
      expect(result.keys).to contain_exactly(:uuid, :name)
    end

    it "handles proc-based fields" do
      result = API::V2::ServerSerializer.serialize(server)
      expect(result).to have_key(:suspended)
      expect(result[:suspended]).to be(false)
    end

    it "respects context for conditional fields" do
      result = API::V2::ServerSerializer.serialize(server, context: { show_sensitive: true })
      expect(result[:token]).to be_present
    end

    it "hides sensitive fields when context does not allow" do
      result = API::V2::ServerSerializer.serialize(server)
      expect(result[:token]).to be_nil
    end
  end

  describe ".serialize_collection" do
    it "returns empty array for nil" do
      expect(API::V2::OrganizationSerializer.serialize_collection(nil)).to eq([])
    end

    it "returns array of serialized objects" do
      orgs = create_list(:organization, 3)
      result = API::V2::OrganizationSerializer.serialize_collection(orgs)
      expect(result).to be_an(Array)
      expect(result.size).to eq(3)
      result.each do |item|
        expect(item).to have_key(:uuid)
      end
    end
  end

  describe "inclusions" do
    it "includes nested resources when requested" do
      server # ensure created
      result = API::V2::OrganizationSerializer.serialize(
        organization,
        include: [:servers],
      )

      expect(result).to have_key(:servers)
      expect(result[:servers]).to be_an(Array)
    end

    it "does not include nested resources by default" do
      server # ensure created
      result = API::V2::OrganizationSerializer.serialize(organization)
      expect(result).not_to have_key(:servers)
    end
  end
end
