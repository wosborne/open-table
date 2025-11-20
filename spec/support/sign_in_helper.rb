module SignInHelper
  def sign_in_as(user)
    visit new_user_session_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: "password123"
    click_button 'Log in'

    expect(page).to have_content('Signed in successfully.'), "Login failed for user #{user.email}"
  end
end
