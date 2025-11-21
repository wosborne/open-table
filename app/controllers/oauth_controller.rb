class OauthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :gmail_callback ]

  def gmail_callback
    auth = request.env["omniauth.auth"]
    account_slug = session[:oauth_account_slug]

    if account_slug.blank?
      redirect_to root_path, alert: "Session expired. Please try again."
      return
    end

    account = current_user.accounts.friendly.find(account_slug)

    if account.blank?
      redirect_to root_path, alert: "Account not found."
      return
    end

    begin
      gmail = account.gmail || account.build_gmail

      gmail.update!(
        email: auth.info.email,
        access_token: auth.credentials.token,
        refresh_token: auth.credentials.refresh_token,
        expires_at: Time.at(auth.credentials.expires_at),
        active: true
      )

      session.delete(:oauth_account_slug)

      redirect_to account_gmail_path(account), notice: "Gmail successfully connected!"
    rescue StandardError => e
      Rails.logger.error "Failed to save Gmail integration: #{e.message}"
      redirect_to account_gmail_path(account), alert: "Failed to connect Gmail. Please try again."
    end
  end

  private

  def failure
    redirect_to root_path, alert: "Authentication failed."
  end
end
