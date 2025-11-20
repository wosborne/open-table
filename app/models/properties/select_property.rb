class Properties::SelectProperty < Property
  before_save :create_options_from_existing_values, if: :type_changed?

  private

  def create_options_from_existing_values
    options.destroy_all

    all_values.each do |value|
      options.find_or_create_by(value: value)
    end
  end
end
