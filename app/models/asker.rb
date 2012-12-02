class Asker < User
  belongs_to :client
  has_many :questions, :foreign_key => :created_for_asker_id

  default_scope where(:role => 'asker')
end