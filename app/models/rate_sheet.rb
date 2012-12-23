class RateSheet < ActiveRecord::Base
  has_many :clients

  def self.includes_clients_by_created_at
    Rails.cache.fetch('rate_sheets_includes_clients_by_created_at', :expires_in => 5.minutes) do
      RateSheet.includes(:clients).order("created_at ASC").all
    end
  end
end
