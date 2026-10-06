class CreatePressCentresAgenciesAndProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :press_centres, id: :uuid do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :agencies, id: :uuid do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :projects, id: :uuid do |t|
      t.string :name, null: false
      t.timestamps
    end
  end
end
