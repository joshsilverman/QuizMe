class ChangeTwiUserIdColumnTypeToBigintOnUser < ActiveRecord::Migration
  def up
      change_column :users, :twi_user_id, :bigint
  end

  def down
      change_column :users, :twi_user_id, :integer
  end
end
