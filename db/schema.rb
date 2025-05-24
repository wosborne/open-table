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

ActiveRecord::Schema[8.0].define(version: 2025_04_29_063239) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "items", force: :cascade do |t|
    t.bigint "table_id", null: false
    t.jsonb "properties", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["properties"], name: "index_items_on_properties", using: :gin
    t.index ["table_id"], name: "index_items_on_table_id"
  end

  create_table "links", force: :cascade do |t|
    t.bigint "from_item_id", null: false
    t.bigint "to_item_id", null: false
    t.bigint "property_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_item_id", "to_item_id"], name: "index_links_on_from_item_id_and_to_item_id", unique: true
    t.index ["from_item_id"], name: "index_links_on_from_item_id"
    t.index ["property_id"], name: "index_links_on_property_id"
    t.index ["to_item_id"], name: "index_links_on_to_item_id"
  end

  create_table "properties", force: :cascade do |t|
    t.bigint "table_id", null: false
    t.string "name", default: "Untitled", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "data_type", default: 0, null: false
    t.bigint "linked_table_id"
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

  create_table "tables", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "items", "tables"
  add_foreign_key "links", "items", column: "from_item_id"
  add_foreign_key "links", "items", column: "to_item_id"
  add_foreign_key "links", "properties"
  add_foreign_key "properties", "tables"
  add_foreign_key "properties", "tables", column: "linked_table_id"
  add_foreign_key "property_options", "properties"
end
