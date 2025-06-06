class CreateViewProperty < ActiveRecord::Migration[8.0]
  def change
    create_table :view_properties do |t|
      t.references :view, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.integer :position, default: 0
      t.boolean :visible, default: true

      t.timestamps
    end

    add_column :views, :position, :integer

    Table.includes(:views).all.each do |table|
      table.views.find_or_create_by(name: "Everything").update(position: 0)

      table.views.where.not(name: "Everything").each_with_index do |view, index|
        view.update(position: index + 1)
      end
    end

    Table.includes(:views, :properties).all.each do |table|
      view_properties_data = table.properties.each_with_index.map { |p, i| { property_id: p.id, position: p.position } }

      table.views.each do |view|
        view.view_properties.create(view_properties_data)
      end
    end
  end
end
