class GmailsController < AccountsController
  def show
    @gmail = current_account.gmail
  end

  def connect
    unless Rails.application.credentials.dig(:google, :client_id).present?
      redirect_to account_gmail_path(current_account), alert: "Gmail integration is not configured. Please contact support."
      return
    end

    session[:oauth_account_slug] = current_account.slug
    redirect_to "/auth/google_oauth2", allow_other_host: true
  end

  def destroy
    current_account.gmail&.revoke_access
    redirect_to account_gmail_path(current_account), notice: "Gmail disconnected successfully."
  end
end
