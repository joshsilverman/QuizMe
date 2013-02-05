class CreateAuthorizations < ActiveRecord::Migration
  def change
    create_table :authorizations do |t|
      t.integer :user_id
      t.string :provider
      t.string :uid
      t.string :name
      t.string :email
      t.string :token
      t.string :secret
      t.string :link

      t.timestamps
    end
  end
end
