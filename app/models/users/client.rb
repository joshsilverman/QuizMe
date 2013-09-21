class Client < User
  belongs_to :rate_sheet
  has_many :askers
  has_many :nudge_types, :foreign_key => :client_id

  default_scope -> { where(:role => 'client') }

  def self.includes_rate_sheets_by_created_at
    Rails.cache.fetch('clients_includes_rate_sheets_by_created_at', :expires_in => 5.minutes) do
      Client.includes(:rate_sheet).order("created_at ASC").all
    end
  end
end