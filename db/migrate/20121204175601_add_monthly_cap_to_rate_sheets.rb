class AddMonthlyCapToRateSheets < ActiveRecord::Migration
  def change
    add_column :rate_sheets, :monthly_cap, :float
  end
end
