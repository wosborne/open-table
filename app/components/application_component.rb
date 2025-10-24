class ApplicationComponent < ViewComponent::Base
  include ActionView::Helpers
  include Rails.application.routes.url_helpers
  include Turbo::FramesHelper
end