Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.dig(:google, :client_id),
    Rails.application.credentials.dig(:google, :client_secret),
    {
      scope: "email,https://www.googleapis.com/auth/gmail.send",
      access_type: "offline",
      prompt: "consent"
    }
end

# Allow GET requests for OmniAuth (required for Rails 7+)
OmniAuth.config.allowed_request_methods = %i[get post]
OmniAuth.config.silence_get_warning = true
