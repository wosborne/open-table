# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
#

require "faker"

# Reset everything
Table.destroy_all

# Create one table and its properties
table = Table.create!(name: "Devices")
color  = Property.create!(name: "Color",  data_type: :text, table:)
size   = Property.create!(name: "Size",   data_type: :text, table:)
weight = Property.create!(name: "Weight", data_type: :text, table:)

# Prepare property IDs
color_id  = color.id
size_id   = size.id
weight_id = weight.id

# Constants
TOTAL_ITEMS = 50_000
BATCH_SIZE  = 1_000

(TOTAL_ITEMS / BATCH_SIZE).times do |batch|
  items = Array.new(BATCH_SIZE) do
    {
      table_id: table.id,
      properties: {
        color_id.to_s  => Faker::Color.color_name,
        size_id.to_s   => Faker::Number.between(from: 1, to: 100),
        weight_id.to_s => Faker::Number.between(from: 1, to: 100)
      },
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  Item.insert_all(items)
  puts "✅ Inserted batch #{batch + 1} (#{(batch + 1) * BATCH_SIZE}/#{TOTAL_ITEMS})"
end
