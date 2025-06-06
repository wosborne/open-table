class View < ApplicationRecord
  extend FriendlyId
  include Positionable

  belongs_to :table
  has_many :filters, dependent: :destroy

  has_many :view_properties, -> { order(:position) }, dependent: :destroy
  has_many :properties, through: :view_properties

  has_many :visible_view_properties, -> { visible.order(:position) }, class_name: "ViewProperty"
  has_many :visible_properties, through: :visible_view_properties, source: :property

  has_many :hidden_view_properties, -> { hidden.order(:position) }, class_name: "ViewProperty"
  has_many :hidden_properties, through: :hidden_view_properties, source: :property

  accepts_nested_attributes_for :filters, allow_destroy: true

  validates :name, presence: true, uniqueness: { scope: :table_id, case_sensitive: false }

  friendly_id :name, use: :slugged

  after_create :create_view_properties_for_each_property

  def should_generate_new_friendly_id?
    name_changed?
  end

  private

  def set_position
    self.position = table.views.count
  end

  def create_view_properties_for_each_property
    table.properties.each do |property|
      view_properties.create(property:)
    end
  end
end
