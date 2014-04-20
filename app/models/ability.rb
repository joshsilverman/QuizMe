class Ability
  include CanCan::Ability

  def initialize(user)
    
    # rails admin
    if user && user.is_admin?
      can :access, :rails_admin
      can :manage, :all  
    end
  end
end
