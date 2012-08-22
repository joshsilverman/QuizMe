class DropAccountsAndRemoveQbFromQuestions < ActiveRecord::Migration
  def up
  	drop_table :accounts
  	remove_column :questions, :qb_lesson_id
  	remove_column :questions, :qb_q_id
  	remove_column :questions, :url
  end

  def down
  	create_table :accounts do |t|
      t.string :name
      t.string :twi_name
      t.string :twi_screen_name
      t.integer :twi_user_id
      t.text :twi_profile_img_url
      t.string :twi_oauth_token
      t.string :twi_oauth_secret
      t.string :fb_oauth_token
      t.string :fb_oauth_secret
      t.string :tum_oauth_token
      t.string :tum_oauth_secret
      t.string :tum_url

      t.timestamps
    end

    add_column :questions, :qb_lesson_id, :integer
  	add_column :questions, :qb_q_id, :integer
  	add_column :questions, :url, :string
  end
end
