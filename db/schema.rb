# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_12_132222) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_users", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "user_id"], name: "index_account_users_on_account_id_and_user_id", unique: true
    t.index ["account_id"], name: "index_account_users_on_account_id"
    t.index ["user_id"], name: "index_account_users_on_user_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "external_account_inventory_units", force: :cascade do |t|
    t.bigint "external_account_id", null: false
    t.bigint "inventory_unit_id", null: false
    t.json "marketplace_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_account_id", "inventory_unit_id"], name: "index_eaiu_on_external_account_and_inventory_unit", unique: true
    t.index ["external_account_id"], name: "index_external_account_inventory_units_on_external_account_id"
    t.index ["inventory_unit_id"], name: "index_external_account_inventory_units_on_inventory_unit_id"
  end

  create_table "external_account_products", force: :cascade do |t|
    t.bigint "external_account_id", null: false
    t.bigint "product_id", null: false
    t.string "external_id"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "last_sync_error"
    t.datetime "last_sync_attempted_at"
    t.string "ebay_category_id"
    t.string "ebay_category_name"
    t.json "ebay_field_mappings"
    t.json "ebay_custom_values"
    t.index ["external_account_id"], name: "index_external_account_products_on_external_account_id"
    t.index ["product_id"], name: "index_external_account_products_on_product_id"
  end

  create_table "external_accounts", force: :cascade do |t|
    t.string "service_name", null: false
    t.string "api_token", null: false
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "domain"
    t.string "refresh_token"
    t.string "ebay_user_id"
    t.string "ebay_username"
    t.string "ebay_display_name"
    t.string "ebay_email"
    t.bigint "inventory_location_id"
    t.index ["account_id"], name: "index_external_accounts_on_account_id"
    t.index ["inventory_location_id"], name: "index_external_accounts_on_inventory_location_id"
  end

  create_table "filters", force: :cascade do |t|
    t.bigint "view_id", null: false
    t.bigint "property_id", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_filters_on_property_id"
    t.index ["view_id", "property_id"], name: "index_filters_on_view_id_and_property_id"
    t.index ["view_id"], name: "index_filters_on_view_id"
  end

  create_table "formulas", force: :cascade do |t|
    t.bigint "property_id", null: false
    t.jsonb "formula_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_formulas_on_property_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.string "scope"
    t.datetime "created_at"
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "inventory_units", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "variant_id", null: false
    t.string "serial_number"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "location_id"
    t.index ["account_id"], name: "index_inventory_units_on_account_id"
    t.index ["location_id"], name: "index_inventory_units_on_location_id"
    t.index ["serial_number"], name: "index_inventory_units_on_serial_number", unique: true
    t.index ["variant_id"], name: "index_inventory_units_on_variant_id"
  end

  create_table "links", force: :cascade do |t|
    t.bigint "from_record_id", null: false
    t.bigint "to_record_id", null: false
    t.bigint "property_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_record_id", "to_record_id"], name: "index_links_on_from_record_id_and_to_record_id", unique: true
    t.index ["from_record_id"], name: "index_links_on_from_record_id"
    t.index ["property_id"], name: "index_links_on_property_id"
    t.index ["to_record_id"], name: "index_links_on_to_record_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.string "address_line_1"
    t.string "address_line_2"
    t.string "city"
    t.string "state"
    t.string "postcode"
    t.string "country"
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_locations_on_account_id"
  end

  create_table "order_line_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "external_line_item_id", null: false
    t.string "sku"
    t.string "title"
    t.integer "quantity", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "inventory_unit_id"
    t.index ["external_line_item_id"], name: "index_order_line_items_on_external_line_item_id"
    t.index ["inventory_unit_id"], name: "index_order_line_items_on_inventory_unit_id"
    t.index ["order_id"], name: "index_order_line_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "external_account_id", null: false
    t.string "external_id", null: false
    t.string "name"
    t.string "currency", null: false
    t.decimal "total_price", precision: 12, scale: 2, null: false
    t.datetime "external_created_at", null: false
    t.string "financial_status"
    t.string "fulfillment_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_account_id"], name: "index_orders_on_external_account_id"
  end

  create_table "product_option_values", force: :cascade do |t|
    t.bigint "product_option_id", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "external_ids", default: {}, null: false
    t.index ["product_option_id"], name: "index_product_option_values_on_product_option_id"
  end

  create_table "product_options", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "external_ids", default: {}, null: false
    t.index ["product_id"], name: "index_product_options_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "brand"
    t.index ["account_id"], name: "index_products_on_account_id"
  end

  create_table "properties", force: :cascade do |t|
    t.bigint "table_id", null: false
    t.string "name", default: "Untitled", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "linked_table_id"
    t.string "format", default: ""
    t.string "type"
    t.string "prefix"
    t.boolean "deletable", default: true
    t.boolean "editable", default: true
    t.index ["linked_table_id"], name: "index_properties_on_linked_table_id"
    t.index ["table_id"], name: "index_properties_on_table_id"
  end

  create_table "property_options", force: :cascade do |t|
    t.bigint "property_id", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_property_options_on_property_id"
  end

  create_table "records", force: :cascade do |t|
    t.bigint "table_id", null: false
    t.jsonb "properties", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["properties"], name: "index_records_on_properties", using: :gin
    t.index ["table_id"], name: "index_records_on_table_id"
  end

  create_table "tables", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.string "slug"
    t.string "type"
    t.integer "last_record_id", default: 0
    t.index ["account_id"], name: "index_tables_on_account_id"
    t.index ["slug"], name: "index_tables_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state_nonce"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["state_nonce"], name: "index_users_on_state_nonce", unique: true
  end

  create_table "variant_option_values", force: :cascade do |t|
    t.bigint "variant_id", null: false
    t.bigint "product_option_id", null: false
    t.bigint "product_option_value_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_option_id"], name: "index_variant_option_values_on_product_option_id"
    t.index ["product_option_value_id"], name: "index_variant_option_values_on_product_option_value_id"
    t.index ["variant_id"], name: "index_variant_option_values_on_variant_id"
  end

  create_table "variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "sku", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "external_ids", default: {}, null: false
    t.index ["product_id"], name: "index_variants_on_product_id"
    t.index ["sku"], name: "index_variants_on_sku", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "view_properties", force: :cascade do |t|
    t.bigint "view_id", null: false
    t.bigint "property_id", null: false
    t.integer "position", default: 0
    t.boolean "visible", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_view_properties_on_property_id"
    t.index ["view_id"], name: "index_view_properties_on_view_id"
  end

  create_table "views", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "table_id", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position"
    t.index ["name", "table_id"], name: "index_views_on_name_and_table_id", unique: true
    t.index ["table_id"], name: "index_views_on_table_id"
  end

  add_foreign_key "account_users", "accounts"
  add_foreign_key "account_users", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "external_account_inventory_units", "external_accounts"
  add_foreign_key "external_account_inventory_units", "inventory_units"
  add_foreign_key "external_account_products", "external_accounts"
  add_foreign_key "external_account_products", "products"
  add_foreign_key "external_accounts", "accounts"
  add_foreign_key "external_accounts", "locations", column: "inventory_location_id"
  add_foreign_key "filters", "properties"
  add_foreign_key "filters", "views"
  add_foreign_key "formulas", "properties"
  add_foreign_key "inventory_units", "accounts"
  add_foreign_key "inventory_units", "locations"
  add_foreign_key "inventory_units", "variants"
  add_foreign_key "links", "properties"
  add_foreign_key "links", "records", column: "from_record_id"
  add_foreign_key "links", "records", column: "to_record_id"
  add_foreign_key "locations", "accounts"
  add_foreign_key "order_line_items", "inventory_units"
  add_foreign_key "order_line_items", "orders"
  add_foreign_key "orders", "external_accounts"
  add_foreign_key "product_option_values", "product_options"
  add_foreign_key "product_options", "products"
  add_foreign_key "products", "accounts"
  add_foreign_key "properties", "tables"
  add_foreign_key "properties", "tables", column: "linked_table_id"
  add_foreign_key "property_options", "properties"
  add_foreign_key "records", "tables"
  add_foreign_key "tables", "accounts"
  add_foreign_key "variant_option_values", "product_option_values"
  add_foreign_key "variant_option_values", "product_options"
  add_foreign_key "variant_option_values", "variants"
  add_foreign_key "variants", "products"
  add_foreign_key "view_properties", "properties"
  add_foreign_key "view_properties", "views"
  add_foreign_key "views", "tables"
end
