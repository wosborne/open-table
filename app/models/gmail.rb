class Gmail < ApplicationRecord
  belongs_to :account

  validates :email, presence: true
  validates :access_token, presence: true, unless: -> { !active? }
  validates :refresh_token, presence: true, unless: -> { !active? }

  scope :active, -> { where(active: true) }

  def token_expired?
    expires_at.nil? || expires_at.past?
  end

  def refresh_token!
    return unless refresh_token.present?
    return unless Rails.application.credentials.dig(:google, :client_id).present?

    client = Signet::OAuth2::Client.new(
      client_id: Rails.application.credentials.dig(:google, :client_id),
      client_secret: Rails.application.credentials.dig(:google, :client_secret),
      refresh_token: refresh_token,
      token_credential_uri: "https://oauth2.googleapis.com/token"
    )

    begin
      credentials = client.refresh!

      update!(
        access_token: credentials["access_token"],
        expires_at: Time.current + credentials["expires_in"].seconds
      )

      true
    rescue StandardError => e
      Rails.logger.error "Failed to refresh Gmail token: #{e.message}"
      false
    end
  end

  def gmail_service
    refresh_token! if token_expired?

    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = access_token
    service
  end

  def revoke_access
    update!(active: false, access_token: nil, refresh_token: nil, expires_at: nil)
  end
end
