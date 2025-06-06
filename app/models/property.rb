class Property < ApplicationRecord
  include Positionable

  enum :data_type, %i[text number date select linked_record formula], suffix: "type"

  belongs_to :table
  belongs_to :linked_table, class_name: "Table", optional: true

  has_many :options, class_name: "PropertyOption", dependent: :destroy
  has_many :view_properties, dependent: :destroy

  has_one :formula, class_name: "Formula", dependent: :destroy

  accepts_nested_attributes_for :options, allow_destroy: true
  accepts_nested_attributes_for :formula, allow_destroy: true

  validates :name, presence: true
  validates :data_type, presence: true
  validates :data_type, inclusion: { in: data_types.keys }
  validates :linked_table, presence: true, if: :linked_record_type?

  before_save :create_options_from_existing_values, if: :data_type_changed?
  before_save :remove_linked_table, unless: :linked_record_type?

  after_create :create_view_properties_for_each_view

  def all_values
    table.items.where("properties ->> ? IS NOT NULL", id.to_s).pluck(Arel.sql("properties ->> '#{id}'")).uniq
  end

  def potential_options
    all_values.map do |value|
      options.find_or_initialize_by(value: value)
    end
  end

  def existing_or_potential_options
    options.any? ? options : potential_options
  end

  private

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

  def set_position
    self.position = table.properties.count
  end

  def create_view_properties_for_each_view
    table.views.each do |view|
      view_properties.create(view:)
    end
  end
end
