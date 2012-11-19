class Client < User
  belongs_to :rate_sheet
  has_many :askers

  default_scope where(:role => 'client')
end