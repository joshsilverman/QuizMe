class CreateRateSheets < ActiveRecord::Migration
  def change
    create_table :rate_sheets do |t|
      t.float :tweet
      t.float :retweet
      t.float :lead
      t.float :conversion
      t.string :title

      t.timestamps
    end
  end
end
