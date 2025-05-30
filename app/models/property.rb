class Property < ApplicationRecord
  enum :data_type, %i[text number date select linked_record], suffix: "type"

  belongs_to :table
  belongs_to :linked_table, class_name: "Table", optional: true

  has_many :options, class_name: "PropertyOption", dependent: :destroy
  accepts_nested_attributes_for :options, allow_destroy: true

  before_validation :set_position, on: :create

  validates :name, presence: true
  validates :data_type, presence: true
  validates :data_type, inclusion: { in: data_types.keys }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :linked_table, presence: true, if: :linked_record_type?

  before_save :create_options_from_existing_values, if: :data_type_changed?
  before_save :remove_linked_table, unless: :linked_record_type?

  def all_values
    table.items.where("properties ->> ? IS NOT NULL", id.to_s).pluck(Arel.sql("properties ->> '#{id}'")).uniq
  end

  def potential_options
    all_values.map do |value|
      options.find_or_initialize_by(value: value)
    end
  end

  private
  def set_position
    self.position = table.properties.count
  end

  def create_options_from_existing_values
    options.destroy_all
    return unless select_type?

    all_values.each do |value|
      options.find_or_create_by(value: value)
    end
  end

  def remove_linked_table
    self.linked_table = nil if linked_record_type?
  end
end
