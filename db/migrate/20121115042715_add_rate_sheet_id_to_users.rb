class AddRateSheetIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :rate_sheet_id, :integer
  end
end
