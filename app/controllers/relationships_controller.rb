class RelationshipsController < ApplicationController
  def create
    relationship = Relationship.find_or_initialize_by({
      follower_id: params[:follower_id], 
      followed_id: params[:followed_id],
      channel: Relationship::WISR})

    relationship.active = true

    if relationship.save
      head 200
    end
  end

  def destroy
    relationship = Relationship.find(params[:id])

    if relationship.wisr?
      relationship.active = false
      relationship.save
      head 200
    else
      head 400
    end
  end
end