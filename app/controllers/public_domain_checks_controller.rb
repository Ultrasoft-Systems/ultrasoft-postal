# frozen_string_literal: true

class PublicDomainChecksController < ApplicationController

  skip_before_action :login_required
  layout "public"

  before_action :find_domain

  def show
  end

  def verify
    if @domain.verified?
      redirect_to public_domain_check_path(@domain.public_token), notice: "This domain has already been verified."
      return
    end

    if @domain.verify_with_dns
      redirect_to public_domain_check_path(@domain.public_token), notice: "#{@domain.name} has been verified successfully. You can now configure your DNS records."
    else
      redirect_to public_domain_check_path(@domain.public_token), alert: "We couldn't verify your domain. Please double check you've added the TXT record correctly."
    end
  end

  def check
    @domain.check_dns(:manual)
    if @domain.dns_ok?
      redirect_to public_domain_check_path(@domain.public_token), notice: "Your DNS records for #{@domain.name} look good!"
    else
      redirect_to public_domain_check_path(@domain.public_token), alert: "There are some issues with your DNS records. Check below for details."
    end
  end

  private

  def find_domain
    @domain = Domain.find_by!(public_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render plain: "Domain not found", status: :not_found
  end

end
