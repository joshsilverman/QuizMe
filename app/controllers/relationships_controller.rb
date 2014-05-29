class RelationshipsController < ApplicationController
  prepend_before_filter :check_for_authentication_token
  before_filter :authenticate_user!
  protect_from_forgery except: [:create, :destroy]

  def create
    relationship = Relationship.find_or_initialize_by({
      follower_id: current_user.id,
      followed_id: params[:followed_id],
      channel: Relationship::WISR})

    relationship.active = true

    if relationship.save
      head 200
    else
      head 400
    end
  end

  def deactivate
    relationship = Relationship
      .where(followed_id: params[:followed_id])
      .where(follower_id: current_user.id).first

    if relationship.try :wisr?
      relationship.active = false
      relationship.save
      head 200
    else
      head 400
    end
  end
end