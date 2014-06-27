module AuthorizationsHelper
	def authenticated_link link, user, expires_at
		url = URI(link)
		params = Rack::Utils.parse_query(url.query)

		
		params[:a] = expireable_auth_token user, expires_at
		url = "#{url.to_s.split('?')[0]}?#{params.to_query}"
		return url
	end

  def expireable_auth_token user, expires_at
    if user.authentication_token.nil?
      user.update!(authentication_token: user.reset_authentication_token)
    end

    query = {
      authentication_token: user.authentication_token, 
      expires_at: expires_at.to_i}.to_query

    Base64.encode64(query)
  end
end