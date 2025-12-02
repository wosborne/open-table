class Property < ApplicationRecord
  include Positionable

  ALL_TYPE_MAP = {
    "id" => "Properties::IdProperty",
    "text" => "Properties::TextProperty",
    "number" => "Properties::NumberProperty",
    "date" => "Properties::DateProperty",
    "select" => "Properties::SelectProperty",
    "checkbox" => "Properties::CheckboxProperty",
    "linked_record" => "Properties::LinkedRecordProperty",
    "formula" => "Properties::FormulaProperty",
    "timestamp" => "Properties::TimestampProperty"
  }.freeze

  TYPE_MAP = ALL_TYPE_MAP.except("fixed", "timestamp")

  VALID_TYPES = ALL_TYPE_MAP.values

  belongs_to :table
  belongs_to :linked_table, class_name: "Table", optional: true

  has_many :options, class_name: "PropertyOption", dependent: :destroy
  has_many :view_properties, dependent: :destroy

  has_one :formula, class_name: "Formula", dependent: :destroy

  accepts_nested_attributes_for :options, allow_destroy: true
  accepts_nested_attributes_for :formula, allow_destroy: true

  validates :name, presence: true
  validates :type, presence: true, inclusion: { in: VALID_TYPES }
  validates :linked_table, presence: true, if: :linked_record_type?

  before_validation :map_type

  before_save :remove_linked_table, unless: :linked_record_type?

  after_create :create_view_properties_for_each_view

  before_destroy :prevent_destroy

  scope :select_type, -> { where(type: TYPE_MAP["select"]) }
  scope :number_type, -> { where(type: TYPE_MAP["number"]) }

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

  ALL_TYPE_MAP.each do |key, klass|
    define_method("#{key}_type?") do
      is_a?(klass.constantize) || type == klass
    end
  end

  def recast
    return self if self.is_a?(type.constantize)
    becomes(type.constantize)
  end

  private

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

  def map_type
    if type_changed? && !VALID_TYPES.include?(type)
      self.type = TYPE_MAP[type]
    end
  end

  def prevent_destroy
    return if deletable
    errors.add(:base, "Cannot delete fixed properties")
    throw(:abort)
  end
end
