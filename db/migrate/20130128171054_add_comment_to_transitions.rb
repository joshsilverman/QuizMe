class AddCommentToTransitions < ActiveRecord::Migration
  def change
    add_column :transitions, :comment, :string
  end
end
