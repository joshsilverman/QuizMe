module AuthorizationsHelper
	def authenticated_link link, user, expires_at
		url = URI(link)
		params = Rack::Utils.parse_query(url.query)
		user.update_attribute :authentication_token, user.reset_authentication_token
		params[:auth] = Base64.encode64({authentication_token: user.authentication_token, expires_at: expires_at.to_i}.to_query)
		"#{url.path}?#{params.to_query}"
	end
end
