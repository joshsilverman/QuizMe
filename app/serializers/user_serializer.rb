class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :twi_screen_name
end
