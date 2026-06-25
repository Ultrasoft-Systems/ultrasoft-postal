# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public Domain Checks", type: :request do
  describe "GET /domain-check/:token" do
    context "when the token is invalid" do
      it "returns a 404" do
        get "/domain-check/invalid-token"
        expect(response.status).to eq 404
      end
    end

    context "when the token is valid" do
      let(:domain) { create(:domain) }

      it "returns a 200" do
        get "/domain-check/#{domain.public_token}"
        expect(response.status).to eq 200
      end

      it "displays the domain name" do
        get "/domain-check/#{domain.public_token}"
        expect(response.body).to include(domain.name)
      end
    end

    context "when the domain is unverified" do
      let(:domain) { create(:domain, :unverified) }

      it "shows the verification instructions" do
        get "/domain-check/#{domain.public_token}"
        expect(response.body).to include(domain.dns_verification_string)
      end
    end

    context "when the domain is verified" do
      let(:domain) { create(:domain) }

      it "shows the DNS setup instructions" do
        get "/domain-check/#{domain.public_token}"
        expect(response.body).to include(domain.spf_record)
      end
    end
  end

  describe "POST /domain-check/:token/verify" do
    context "when the domain is already verified" do
      let(:domain) { create(:domain) }

      it "redirects with a notice" do
        post "/domain-check/#{domain.public_token}/verify"
        expect(response).to redirect_to(public_domain_check_path(domain.public_token))
        follow_redirect!
        expect(response.body).to include("already been verified")
      end
    end

    context "when the domain is unverified" do
      let(:domain) { create(:domain, :unverified) }

      context "when DNS verification succeeds" do
        before do
          allow_any_instance_of(Domain).to receive(:verify_with_dns).and_return(true) # rubocop:disable RSpec/AnyInstance
        end

        it "redirects with a success notice" do
          post "/domain-check/#{domain.public_token}/verify"
          expect(response).to redirect_to(public_domain_check_path(domain.public_token))
        end
      end

      context "when DNS verification fails" do
        before do
          allow_any_instance_of(Domain).to receive(:verify_with_dns).and_return(false) # rubocop:disable RSpec/AnyInstance
        end

        it "redirects with an error alert" do
          post "/domain-check/#{domain.public_token}/verify"
          expect(response).to redirect_to(public_domain_check_path(domain.public_token))
          expect(flash[:alert]).to include("couldn't verify")
        end
      end
    end
  end

  describe "POST /domain-check/:token/check" do
    let(:domain) { create(:domain) }

    context "when DNS records are OK" do
      before do
        allow_any_instance_of(Domain).to receive(:check_dns).and_return(true) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Domain).to receive(:dns_ok?).and_return(true) # rubocop:disable RSpec/AnyInstance
      end

      it "redirects with a success notice" do
        post "/domain-check/#{domain.public_token}/check"
        expect(response).to redirect_to(public_domain_check_path(domain.public_token))
        expect(flash[:notice]).to include("look good")
      end
    end

    context "when DNS records have issues" do
      before do
        allow_any_instance_of(Domain).to receive(:check_dns).and_return(false) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Domain).to receive(:dns_ok?).and_return(false) # rubocop:disable RSpec/AnyInstance
      end

      it "redirects with an error alert" do
        post "/domain-check/#{domain.public_token}/check"
        expect(response).to redirect_to(public_domain_check_path(domain.public_token))
        expect(flash[:alert]).to include("some issues")
      end
    end
  end
end
