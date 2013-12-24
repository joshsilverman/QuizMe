class DropTableRateSheets < ActiveRecord::Migration
  def up
    drop_table :rate_sheets

    remove_index :users, column: :rate_sheet_id
    remove_column :users, :rate_sheet_id, :integer

    remove_column :users, :client_nudge, :boolean
  end

  def down
    create_table :rate_sheets do |t|
      t.float :tweet
      t.float :retweet
      t.float :lead
      t.float :conversion
      t.string :title
      t.string :logo_image
      t.float :monthly_cap

      t.timestamps
    end

    add_column :users, :rate_sheet_id, :integer
    add_column :users, :client_nudge, :boolean

    add_index :users, column: :rate_sheet_id
  end
end
