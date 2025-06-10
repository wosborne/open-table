require "csv"

module Tables
  class ProcessImportCsv < ApplicationService
    def initialize(table)
      @table = table
    end

    def call
      process_import_file
    end

    def process_import_file
      return unless @table.import.attached?

      csv_data = @table.import.download
      CSV.parse(csv_data, headers: true) do |row|
        item_properties = {}

        row.each do |header, value|
          property = @table.properties.find_or_create_by(name: header, type: :text)
          item_properties[property.id] = value
        end

        @table.items.create(properties: item_properties)
      end

      @table.import.destroy
    end
  end
end
