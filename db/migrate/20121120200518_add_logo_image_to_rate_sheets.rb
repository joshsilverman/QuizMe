class AddLogoImageToRateSheets < ActiveRecord::Migration
  def change
    add_column :rate_sheets, :logo_image, :string
  end
end
