class Asker < User
  belongs_to :client

  default_scope where(:role => 'asker')
end