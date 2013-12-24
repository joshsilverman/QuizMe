class Client < User
  has_many :askers
  has_many :nudge_types, :foreign_key => :client_id

  default_scope -> { where(:role => 'client') }

end