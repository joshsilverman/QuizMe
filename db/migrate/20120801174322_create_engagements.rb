class CreateEngagements < ActiveRecord::Migration
  def change
    create_table :engagements do |t|
      t.string :date
      t.string :engagement_type
      t.string :text
      t.string :provider
      t.string :provider_post_id
      t.string  :twi_in_reply_to_status_id
      t.integer :user_id
      t.integer :account_id
      t.integer :post_id

      t.timestamps
    end
  end
end
