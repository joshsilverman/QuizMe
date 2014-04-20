# RailsAdmin config file. Generated on April 19, 2014 19:53
# See github.com/sferik/rails_admin for more informations
Rails.application.eager_load!

# RailsAdmin.config.included_models = ActiveRecord::Base.descendants.map!(&:name)
RailsAdmin.config do |config|


  ################  Global configuration  ################

  # Set the admin name here (optional second array element will appear in red). For example:
  config.main_app_name = ['Quizmemanager', 'Admin']
  # or for a more dynamic name:
  # config.main_app_name = Proc.new { |controller| [Rails.application.engine_name.titleize, controller.params['action'].titleize] }

  # RailsAdmin may need a way to know who the current user is]
  config.current_user_method { current_user if current_user.is_admin? } # auto-generated
  
  config.authorize_with :cancan

  # If you want to track changes on your models:
  # config.audit_with :history, 'User'

  # Or with a PaperTrail: (you need to install it first)
  # config.audit_with :paper_trail, 'User'

  # Display empty fields in show views:
  # config.compact_show_view = false

  # Number of default rows per-page:
  # config.default_items_per_page = 20

  # Exclude specific models (keep the others):
  # config.excluded_models = ['ActiveRecord::SchemaMigration', 'Answer', 'Asker', 'Authorization', 'Badge', 'Client', 'Conversation', 'Delayed::Backend::ActiveRecord::Job', 'EmailAsker', 'Issuance', 'Moderation', 'Moderator', 'ModeratorTransition', 'NudgeType', 'Post', 'PostModeration', 'Publication', 'PublicationQueue', 'Question', 'QuestionModeration', 'Relationship', 'Tag', 'Topic', 'Transition', 'TwitterAsker', 'User']

  # Include specific models (exclude the others):
  config.included_models = ['ActiveRecord::SchemaMigration', 'Answer', 'Asker', 'Authorization', 'Badge', 'Client', 'Conversation', 'Delayed::Backend::ActiveRecord::Job', 'EmailAsker', 'Issuance', 'Moderation', 'Moderator', 'ModeratorTransition', 'NudgeType', 'Post', 'PostModeration', 'Publication', 'PublicationQueue', 'Question', 'QuestionModeration', 'Relationship', 'Tag', 'Topic', 'Transition', 'TwitterAsker', 'User']

  # Label methods for model instances:
  # config.label_methods << :description # Default is [:name, :title]


  ################  Model configuration  ################

  # Each model configuration can alternatively:
  #   - stay here in a `config.model 'ModelName' do ... end` block
  #   - go in the model definition file in a `rails_admin do ... end` block

  # This is your choice to make:
  #   - This initializer is loaded once at startup (modifications will show up when restarting the application) but all RailsAdmin configuration would stay in one place.
  #   - Models are reloaded at each request in development mode (when modified), which may smooth your RailsAdmin development workflow.


  # Now you probably need to tour the wiki a bit: https://github.com/sferik/rails_admin/wiki
  # Anyway, here is how RailsAdmin saw your application's models when you ran the initializer:



  ###  ActiveRecord::SchemaMigration  ###

  # config.model 'ActiveRecord::SchemaMigration' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your active_record/schema_migration.rb model definition

  #   # Found associations:



  #   # Found columns:

  #     configure :version, :string 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Answer  ###

  # config.model 'Answer' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your answer.rb model definition

  #   # Found associations:

  #     configure :question, :belongs_to_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :correct, :boolean 
  #     configure :question_id, :integer         # Hidden 
  #     configure :text, :text 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :questionbase_id, :integer 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Asker  ###

  # config.model 'Asker' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your asker.rb model definition

  #   # Found associations:

  #     configure :new_user_question, :belongs_to_association 
  #     configure :client, :belongs_to_association 
  #     configure :search_term, :belongs_to_association 
  #     configure :tags, :has_and_belongs_to_many_association 
  #     configure :authorizations, :has_many_association 
  #     configure :questions, :has_many_association 
  #     configure :askables, :has_many_association 
  #     configure :transitions, :has_many_association 
  #     configure :stats, :has_many_association         # Hidden 
  #     configure :posts, :has_many_association 
  #     configure :publications, :has_many_association 
  #     configure :engagements, :has_many_association 
  #     configure :publication_queue, :has_one_association 
  #     configure :badges, :has_many_association 
  #     configure :issuances, :has_many_association 
  #     configure :follow_relationships, :has_many_association 
  #     configure :follows, :has_many_association 
  #     configure :follows_with_inactive, :has_many_association 
  #     configure :asker_follows, :has_many_association 
  #     configure :follower_relationships, :has_many_association 
  #     configure :followers, :has_many_association 
  #     configure :followers_with_inactive, :has_many_association 
  #     configure :moderators, :has_many_association 
  #     configure :related_askers, :has_and_belongs_to_many_association 
  #     configure :topics, :has_and_belongs_to_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :twi_name, :string 
  #     configure :twi_screen_name, :string 
  #     configure :twi_user_id, :integer 
  #     configure :twi_profile_img_url, :text 
  #     configure :twi_oauth_token, :string 
  #     configure :twi_oauth_secret, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :role, :string 
  #     configure :name, :string 
  #     configure :posts_per_day, :integer 
  #     configure :description, :text 
  #     configure :new_user_q_id, :integer         # Hidden 
  #     configure :published, :boolean 
  #     configure :author_id, :integer 
  #     configure :learner_level, :string 
  #     configure :last_interaction_at, :datetime 
  #     configure :last_answer_at, :datetime 
  #     configure :client_id, :integer         # Hidden 
  #     configure :lifecycle_segment, :integer 
  #     configure :activity_segment, :integer 
  #     configure :interaction_segment, :integer 
  #     configure :author_segment, :integer 
  #     configure :email, :string 
  #     configure :password, :password         # Hidden 
  #     configure :password_confirmation, :password         # Hidden 
  #     configure :reset_password_token, :string         # Hidden 
  #     configure :reset_password_sent_at, :datetime 
  #     configure :remember_created_at, :datetime 
  #     configure :sign_in_count, :integer 
  #     configure :current_sign_in_at, :datetime 
  #     configure :last_sign_in_at, :datetime 
  #     configure :current_sign_in_ip, :string 
  #     configure :last_sign_in_ip, :string 
  #     configure :subscribed, :boolean 
  #     configure :moderator_segment, :integer 
  #     configure :search_term_topic_id, :integer         # Hidden 
  #     configure :authentication_token, :string 
  #     configure :communication_preference, :integer 
  #     configure :last_email_request_at, :datetime 
  #     configure :last_followback_failure, :datetime 
  #     configure :subject, :string 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Authorization  ###

  # config.model 'Authorization' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your authorization.rb model definition

  #   # Found associations:

  #     configure :user, :belongs_to_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :user_id, :integer         # Hidden 
  #     configure :provider, :string 
  #     configure :uid, :string 
  #     configure :name, :string 
  #     configure :email, :string 
  #     configure :token, :string 
  #     configure :secret, :string 
  #     configure :link, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Badge  ###

  # config.model 'Badge' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your badge.rb model definition

  #   # Found associations:

  #     configure :asker, :belongs_to_association 
  #     configure :users, :has_many_association 
  #     configure :issuances, :has_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :asker_id, :integer         # Hidden 
  #     configure :title, :string 
  #     configure :filename, :string 
  #     configure :description, :text 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :segment_type, :integer 
  #     configure :to_segment, :integer 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Client  ###

  # config.model 'Client' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your client.rb model definition

  #   # Found associations:

  #     configure :search_term, :belongs_to_association 
  #     configure :tags, :has_and_belongs_to_many_association 
  #     configure :authorizations, :has_many_association 
  #     configure :questions, :has_many_association 
  #     configure :askables, :has_many_association 
  #     configure :transitions, :has_many_association 
  #     configure :stats, :has_many_association         # Hidden 
  #     configure :posts, :has_many_association 
  #     configure :publications, :has_many_association 
  #     configure :engagements, :has_many_association 
  #     configure :publication_queue, :has_one_association 
  #     configure :badges, :has_many_association 
  #     configure :issuances, :has_many_association 
  #     configure :follow_relationships, :has_many_association 
  #     configure :follows, :has_many_association 
  #     configure :follows_with_inactive, :has_many_association 
  #     configure :asker_follows, :has_many_association 
  #     configure :follower_relationships, :has_many_association 
  #     configure :followers, :has_many_association 
  #     configure :followers_with_inactive, :has_many_association 
  #     configure :askers, :has_many_association 
  #     configure :nudge_types, :has_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :twi_name, :string 
  #     configure :twi_screen_name, :string 
  #     configure :twi_user_id, :integer 
  #     configure :twi_profile_img_url, :text 
  #     configure :twi_oauth_token, :string 
  #     configure :twi_oauth_secret, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :role, :string 
  #     configure :name, :string 
  #     configure :posts_per_day, :integer 
  #     configure :description, :text 
  #     configure :new_user_q_id, :integer 
  #     configure :published, :boolean 
  #     configure :author_id, :integer 
  #     configure :learner_level, :string 
  #     configure :last_interaction_at, :datetime 
  #     configure :last_answer_at, :datetime 
  #     configure :client_id, :integer 
  #     configure :lifecycle_segment, :integer 
  #     configure :activity_segment, :integer 
  #     configure :interaction_segment, :integer 
  #     configure :author_segment, :integer 
  #     configure :email, :string 
  #     configure :password, :password         # Hidden 
  #     configure :password_confirmation, :password         # Hidden 
  #     configure :reset_password_token, :string         # Hidden 
  #     configure :reset_password_sent_at, :datetime 
  #     configure :remember_created_at, :datetime 
  #     configure :sign_in_count, :integer 
  #     configure :current_sign_in_at, :datetime 
  #     configure :last_sign_in_at, :datetime 
  #     configure :current_sign_in_ip, :string 
  #     configure :last_sign_in_ip, :string 
  #     configure :subscribed, :boolean 
  #     configure :moderator_segment, :integer 
  #     configure :search_term_topic_id, :integer         # Hidden 
  #     configure :authentication_token, :string 
  #     configure :communication_preference, :integer 
  #     configure :last_email_request_at, :datetime 
  #     configure :last_followback_failure, :datetime 
  #     configure :subject, :string 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Conversation  ###

  # config.model 'Conversation' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your conversation.rb model definition

  #   # Found associations:

  #     configure :publication, :belongs_to_association 
  #     configure :post, :belongs_to_association 
  #     configure :posts, :has_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :publication_id, :integer         # Hidden 
  #     configure :post_id, :integer         # Hidden 
  #     configure :user_id, :integer 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Delayed::Backend::ActiveRecord::Job  ###

  # config.model 'Delayed::Backend::ActiveRecord::Job' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your delayed/backend/active_record/job.rb model definition

  #   # Found associations:



  #   # Found columns:

  #     configure :id, :integer 
  #     configure :priority, :integer 
  #     configure :attempts, :integer 
  #     configure :handler, :text 
  #     configure :last_error, :text 
  #     configure :run_at, :datetime 
  #     configure :locked_at, :datetime 
  #     configure :failed_at, :datetime 
  #     configure :locked_by, :string 
  #     configure :queue, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  EmailAsker  ###

  # config.model 'EmailAsker' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your email_asker.rb model definition

  #   # Found associations:

  #     configure :new_user_question, :belongs_to_association 
  #     configure :client, :belongs_to_association 
  #     configure :search_term, :belongs_to_association 
  #     configure :tags, :has_and_belongs_to_many_association 
  #     configure :authorizations, :has_many_association 
  #     configure :questions, :has_many_association 
  #     configure :askables, :has_many_association 
  #     configure :transitions, :has_many_association 
  #     configure :stats, :has_many_association         # Hidden 
  #     configure :posts, :has_many_association 
  #     configure :publications, :has_many_association 
  #     configure :engagements, :has_many_association 
  #     configure :publication_queue, :has_one_association 
  #     configure :badges, :has_many_association 
  #     configure :issuances, :has_many_association 
  #     configure :follow_relationships, :has_many_association 
  #     configure :follows, :has_many_association 
  #     configure :follows_with_inactive, :has_many_association 
  #     configure :asker_follows, :has_many_association 
  #     configure :follower_relationships, :has_many_association 
  #     configure :followers, :has_many_association 
  #     configure :followers_with_inactive, :has_many_association 
  #     configure :moderators, :has_many_association 
  #     configure :related_askers, :has_and_belongs_to_many_association 
  #     configure :topics, :has_and_belongs_to_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :twi_name, :string 
  #     configure :twi_screen_name, :string 
  #     configure :twi_user_id, :integer 
  #     configure :twi_profile_img_url, :text 
  #     configure :twi_oauth_token, :string 
  #     configure :twi_oauth_secret, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :role, :string 
  #     configure :name, :string 
  #     configure :posts_per_day, :integer 
  #     configure :description, :text 
  #     configure :new_user_q_id, :integer         # Hidden 
  #     configure :published, :boolean 
  #     configure :author_id, :integer 
  #     configure :learner_level, :string 
  #     configure :last_interaction_at, :datetime 
  #     configure :last_answer_at, :datetime 
  #     configure :client_id, :integer         # Hidden 
  #     configure :lifecycle_segment, :integer 
  #     configure :activity_segment, :integer 
  #     configure :interaction_segment, :integer 
  #     configure :author_segment, :integer 
  #     configure :email, :string 
  #     configure :password, :password         # Hidden 
  #     configure :password_confirmation, :password         # Hidden 
  #     configure :reset_password_token, :string         # Hidden 
  #     configure :reset_password_sent_at, :datetime 
  #     configure :remember_created_at, :datetime 
  #     configure :sign_in_count, :integer 
  #     configure :current_sign_in_at, :datetime 
  #     configure :last_sign_in_at, :datetime 
  #     configure :current_sign_in_ip, :string 
  #     configure :last_sign_in_ip, :string 
  #     configure :subscribed, :boolean 
  #     configure :moderator_segment, :integer 
  #     configure :search_term_topic_id, :integer         # Hidden 
  #     configure :authentication_token, :string 
  #     configure :communication_preference, :integer 
  #     configure :last_email_request_at, :datetime 
  #     configure :last_followback_failure, :datetime 
  #     configure :subject, :string 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Issuance  ###

  # config.model 'Issuance' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your issuance.rb model definition

  #   # Found associations:

  #     configure :user, :belongs_to_association 
  #     configure :badge, :belongs_to_association 
  #     configure :asker, :belongs_to_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :user_id, :integer         # Hidden 
  #     configure :badge_id, :integer         # Hidden 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :asker_id, :integer         # Hidden 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Moderation  ###

  # config.model 'Moderation' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your moderation.rb model definition

  #   # Found associations:

  #     configure :post, :belongs_to_association 
  #     configure :moderator, :belongs_to_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :post_id, :integer         # Hidden 
  #     configure :user_id, :integer         # Hidden 
  #     configure :type_id, :integer 
  #     configure :accepted, :boolean 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :question_id, :integer 
  #     configure :active, :boolean 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Moderator  ###

  # config.model 'Moderator' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your moderator.rb model definition

  #   # Found associations:

  #     configure :search_term, :belongs_to_association 
  #     configure :tags, :has_and_belongs_to_many_association 
  #     configure :authorizations, :has_many_association 
  #     configure :questions, :has_many_association 
  #     configure :askables, :has_many_association 
  #     configure :transitions, :has_many_association 
  #     configure :stats, :has_many_association         # Hidden 
  #     configure :posts, :has_many_association 
  #     configure :publications, :has_many_association 
  #     configure :engagements, :has_many_association 
  #     configure :publication_queue, :has_one_association 
  #     configure :badges, :has_many_association 
  #     configure :issuances, :has_many_association 
  #     configure :follow_relationships, :has_many_association 
  #     configure :follows, :has_many_association 
  #     configure :follows_with_inactive, :has_many_association 
  #     configure :asker_follows, :has_many_association 
  #     configure :follower_relationships, :has_many_association 
  #     configure :followers, :has_many_association 
  #     configure :followers_with_inactive, :has_many_association 
  #     configure :moderations, :has_many_association 
  #     configure :post_moderations, :has_many_association 
  #     configure :question_moderations, :has_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :twi_name, :string 
  #     configure :twi_screen_name, :string 
  #     configure :twi_user_id, :integer 
  #     configure :twi_profile_img_url, :text 
  #     configure :twi_oauth_token, :string 
  #     configure :twi_oauth_secret, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :role, :string 
  #     configure :name, :string 
  #     configure :posts_per_day, :integer 
  #     configure :description, :text 
  #     configure :new_user_q_id, :integer 
  #     configure :published, :boolean 
  #     configure :author_id, :integer 
  #     configure :learner_level, :string 
  #     configure :last_interaction_at, :datetime 
  #     configure :last_answer_at, :datetime 
  #     configure :client_id, :integer 
  #     configure :lifecycle_segment, :integer 
  #     configure :activity_segment, :integer 
  #     configure :interaction_segment, :integer 
  #     configure :author_segment, :integer 
  #     configure :email, :string 
  #     configure :password, :password         # Hidden 
  #     configure :password_confirmation, :password         # Hidden 
  #     configure :reset_password_token, :string         # Hidden 
  #     configure :reset_password_sent_at, :datetime 
  #     configure :remember_created_at, :datetime 
  #     configure :sign_in_count, :integer 
  #     configure :current_sign_in_at, :datetime 
  #     configure :last_sign_in_at, :datetime 
  #     configure :current_sign_in_ip, :string 
  #     configure :last_sign_in_ip, :string 
  #     configure :subscribed, :boolean 
  #     configure :moderator_segment, :integer 
  #     configure :search_term_topic_id, :integer         # Hidden 
  #     configure :authentication_token, :string 
  #     configure :communication_preference, :integer 
  #     configure :last_email_request_at, :datetime 
  #     configure :last_followback_failure, :datetime 
  #     configure :subject, :string 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  ModeratorTransition  ###

  # config.model 'ModeratorTransition' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your moderator_transition.rb model definition

  #   # Found associations:

  #     configure :user, :belongs_to_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :from_segment, :integer 
  #     configure :to_segment, :integer 
  #     configure :segment_type, :integer 
  #     configure :user_id, :integer         # Hidden 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :comment, :string 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  NudgeType  ###

  # config.model 'NudgeType' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your nudge_type.rb model definition

  #   # Found associations:

  #     configure :client, :belongs_to_association 
  #     configure :posts, :has_many_association 
  #     configure :conversations, :has_many_association 
  #     configure :users, :has_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :client_id, :integer         # Hidden 
  #     configure :url, :string 
  #     configure :text, :text 
  #     configure :active, :boolean 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :automatic, :boolean 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Post  ###

  # config.model 'Post' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your post.rb model definition

  #   # Found associations:

  #     configure :user, :belongs_to_association 
  #     configure :parent, :belongs_to_association 
  #     configure :publication, :belongs_to_association 
  #     configure :conversation, :belongs_to_association 
  #     configure :in_reply_to_user, :belongs_to_association 
  #     configure :nudge_type, :belongs_to_association 
  #     configure :in_reply_to_question, :belongs_to_association 
  #     configure :question, :belongs_to_association 
  #     configure :tags, :has_and_belongs_to_many_association 
  #     configure :child, :has_one_association 
  #     configure :conversations, :has_many_association 
  #     configure :post_moderations, :has_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :user_id, :integer         # Hidden 
  #     configure :provider, :string 
  #     configure :text, :text 
  #     configure :provider_post_id, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :in_reply_to_post_id, :integer         # Hidden 
  #     configure :publication_id, :integer         # Hidden 
  #     configure :conversation_id, :integer         # Hidden 
  #     configure :requires_action, :boolean 
  #     configure :in_reply_to_user_id, :integer         # Hidden 
  #     configure :posted_via_app, :boolean 
  #     configure :url, :string 
  #     configure :spam, :boolean 
  #     configure :autospam, :boolean 
  #     configure :interaction_type, :integer 
  #     configure :correct, :boolean 
  #     configure :intention, :string 
  #     configure :autocorrect, :boolean 
  #     configure :nudge_type_id, :integer         # Hidden 
  #     configure :in_reply_to_question_id, :integer         # Hidden 
  #     configure :converted, :boolean 
  #     configure :question_id, :integer         # Hidden 
  #     configure :moderator_id, :integer 
  #     configure :moderation_trigger_type_id, :integer 
  #     configure :is_reengagement, :boolean 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  PostModeration  ###

  # config.model 'PostModeration' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your post_moderation.rb model definition

  #   # Found associations:

  #     configure :post, :belongs_to_association 
  #     configure :moderator, :belongs_to_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :post_id, :integer         # Hidden 
  #     configure :user_id, :integer         # Hidden 
  #     configure :type_id, :integer 
  #     configure :accepted, :boolean 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :question_id, :integer 
  #     configure :active, :boolean 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Publication  ###

  # config.model 'Publication' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your publication.rb model definition

  #   # Found associations:

  #     configure :question, :belongs_to_association 
  #     configure :asker, :belongs_to_association 
  #     configure :publication_queue, :belongs_to_association 
  #     configure :conversations, :has_many_association 
  #     configure :posts, :has_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :question_id, :integer         # Hidden 
  #     configure :asker_id, :integer         # Hidden 
  #     configure :url, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :publication_queue_id, :integer         # Hidden 
  #     configure :published, :boolean 
  #     configure :first_posted_at, :datetime 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  PublicationQueue  ###

  # config.model 'PublicationQueue' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your publication_queue.rb model definition

  #   # Found associations:

  #     configure :asker, :belongs_to_association 
  #     configure :publications, :has_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :asker_id, :integer         # Hidden 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :index, :integer 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Question  ###

  # config.model 'Question' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your question.rb model definition

  #   # Found associations:

  #     configure :user, :belongs_to_association 
  #     configure :asker, :belongs_to_association 
  #     configure :posts, :has_many_association 
  #     configure :in_reply_to_posts, :has_many_association 
  #     configure :answers, :has_many_association 
  #     configure :publications, :has_many_association 
  #     configure :question_moderations, :has_many_association 
  #     configure :topics, :has_and_belongs_to_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :text, :text 
  #     configure :topic_id, :integer 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :user_id, :integer         # Hidden 
  #     configure :status, :integer 
  #     configure :created_for_asker_id, :integer         # Hidden 
  #     configure :priority, :boolean 
  #     configure :hashtag, :string 
  #     configure :resource_url, :text 
  #     configure :slug, :string 
  #     configure :hint, :string 
  #     configure :publishable, :boolean 
  #     configure :inaccurate, :boolean 
  #     configure :ungrammatical, :boolean 
  #     configure :bad_answers, :boolean 
  #     configure :moderation_trigger_type_id, :integer 
  #     configure :needs_edits, :boolean 
  #     configure :_correct_answer_id, :integer 
  #     configure :questionbase_id, :integer 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  QuestionModeration  ###

  # config.model 'QuestionModeration' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your question_moderation.rb model definition

  #   # Found associations:

  #     configure :post, :belongs_to_association 
  #     configure :moderator, :belongs_to_association 
  #     configure :question, :belongs_to_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :post_id, :integer         # Hidden 
  #     configure :user_id, :integer         # Hidden 
  #     configure :type_id, :integer 
  #     configure :accepted, :boolean 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :question_id, :integer         # Hidden 
  #     configure :active, :boolean 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Relationship  ###

  # config.model 'Relationship' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your relationship.rb model definition

  #   # Found associations:

  #     configure :follower, :belongs_to_association 
  #     configure :followed, :belongs_to_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :follower_id, :integer         # Hidden 
  #     configure :followed_id, :integer         # Hidden 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :type_id, :integer 
  #     configure :active, :boolean 
  #     configure :pending, :boolean 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Tag  ###

  # config.model 'Tag' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your tag.rb model definition

  #   # Found associations:

  #     configure :posts, :has_and_belongs_to_many_association 
  #     configure :users, :has_and_belongs_to_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :name, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Topic  ###

  # config.model 'Topic' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your topic.rb model definition

  #   # Found associations:

  #     configure :search_term_users, :has_many_association 
  #     configure :questions, :has_and_belongs_to_many_association 
  #     configure :askers, :has_and_belongs_to_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :name, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :type_id, :integer 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  Transition  ###

  # config.model 'Transition' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your transition.rb model definition

  #   # Found associations:

  #     configure :user, :belongs_to_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :from_segment, :integer 
  #     configure :to_segment, :integer 
  #     configure :segment_type, :integer 
  #     configure :user_id, :integer         # Hidden 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :comment, :string 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  TwitterAsker  ###

  # config.model 'TwitterAsker' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your twitter_asker.rb model definition

  #   # Found associations:

  #     configure :new_user_question, :belongs_to_association 
  #     configure :client, :belongs_to_association 
  #     configure :search_term, :belongs_to_association 
  #     configure :tags, :has_and_belongs_to_many_association 
  #     configure :authorizations, :has_many_association 
  #     configure :questions, :has_many_association 
  #     configure :askables, :has_many_association 
  #     configure :transitions, :has_many_association 
  #     configure :stats, :has_many_association         # Hidden 
  #     configure :posts, :has_many_association 
  #     configure :publications, :has_many_association 
  #     configure :engagements, :has_many_association 
  #     configure :publication_queue, :has_one_association 
  #     configure :badges, :has_many_association 
  #     configure :issuances, :has_many_association 
  #     configure :follow_relationships, :has_many_association 
  #     configure :follows, :has_many_association 
  #     configure :follows_with_inactive, :has_many_association 
  #     configure :asker_follows, :has_many_association 
  #     configure :follower_relationships, :has_many_association 
  #     configure :followers, :has_many_association 
  #     configure :followers_with_inactive, :has_many_association 
  #     configure :moderators, :has_many_association 
  #     configure :related_askers, :has_and_belongs_to_many_association 
  #     configure :topics, :has_and_belongs_to_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :twi_name, :string 
  #     configure :twi_screen_name, :string 
  #     configure :twi_user_id, :integer 
  #     configure :twi_profile_img_url, :text 
  #     configure :twi_oauth_token, :string 
  #     configure :twi_oauth_secret, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :role, :string 
  #     configure :name, :string 
  #     configure :posts_per_day, :integer 
  #     configure :description, :text 
  #     configure :new_user_q_id, :integer         # Hidden 
  #     configure :published, :boolean 
  #     configure :author_id, :integer 
  #     configure :learner_level, :string 
  #     configure :last_interaction_at, :datetime 
  #     configure :last_answer_at, :datetime 
  #     configure :client_id, :integer         # Hidden 
  #     configure :lifecycle_segment, :integer 
  #     configure :activity_segment, :integer 
  #     configure :interaction_segment, :integer 
  #     configure :author_segment, :integer 
  #     configure :email, :string 
  #     configure :password, :password         # Hidden 
  #     configure :password_confirmation, :password         # Hidden 
  #     configure :reset_password_token, :string         # Hidden 
  #     configure :reset_password_sent_at, :datetime 
  #     configure :remember_created_at, :datetime 
  #     configure :sign_in_count, :integer 
  #     configure :current_sign_in_at, :datetime 
  #     configure :last_sign_in_at, :datetime 
  #     configure :current_sign_in_ip, :string 
  #     configure :last_sign_in_ip, :string 
  #     configure :subscribed, :boolean 
  #     configure :moderator_segment, :integer 
  #     configure :search_term_topic_id, :integer         # Hidden 
  #     configure :authentication_token, :string 
  #     configure :communication_preference, :integer 
  #     configure :last_email_request_at, :datetime 
  #     configure :last_followback_failure, :datetime 
  #     configure :subject, :string 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end


  ###  User  ###

  # config.model 'User' do

  #   # You can copy this to a 'rails_admin do ... end' block inside your user.rb model definition

  #   # Found associations:

  #     configure :search_term, :belongs_to_association 
  #     configure :tags, :has_and_belongs_to_many_association 
  #     configure :authorizations, :has_many_association 
  #     configure :questions, :has_many_association 
  #     configure :askables, :has_many_association 
  #     configure :transitions, :has_many_association 
  #     configure :stats, :has_many_association         # Hidden 
  #     configure :posts, :has_many_association 
  #     configure :publications, :has_many_association 
  #     configure :engagements, :has_many_association 
  #     configure :publication_queue, :has_one_association 
  #     configure :badges, :has_many_association 
  #     configure :issuances, :has_many_association 
  #     configure :follow_relationships, :has_many_association 
  #     configure :follows, :has_many_association 
  #     configure :follows_with_inactive, :has_many_association 
  #     configure :asker_follows, :has_many_association 
  #     configure :follower_relationships, :has_many_association 
  #     configure :followers, :has_many_association 
  #     configure :followers_with_inactive, :has_many_association 

  #   # Found columns:

  #     configure :id, :integer 
  #     configure :twi_name, :string 
  #     configure :twi_screen_name, :string 
  #     configure :twi_user_id, :integer 
  #     configure :twi_profile_img_url, :text 
  #     configure :twi_oauth_token, :string 
  #     configure :twi_oauth_secret, :string 
  #     configure :created_at, :datetime 
  #     configure :updated_at, :datetime 
  #     configure :role, :string 
  #     configure :name, :string 
  #     configure :posts_per_day, :integer 
  #     configure :description, :text 
  #     configure :new_user_q_id, :integer 
  #     configure :published, :boolean 
  #     configure :author_id, :integer 
  #     configure :learner_level, :string 
  #     configure :last_interaction_at, :datetime 
  #     configure :last_answer_at, :datetime 
  #     configure :client_id, :integer 
  #     configure :lifecycle_segment, :integer 
  #     configure :activity_segment, :integer 
  #     configure :interaction_segment, :integer 
  #     configure :author_segment, :integer 
  #     configure :email, :string 
  #     configure :password, :password         # Hidden 
  #     configure :password_confirmation, :password         # Hidden 
  #     configure :reset_password_token, :string         # Hidden 
  #     configure :reset_password_sent_at, :datetime 
  #     configure :remember_created_at, :datetime 
  #     configure :sign_in_count, :integer 
  #     configure :current_sign_in_at, :datetime 
  #     configure :last_sign_in_at, :datetime 
  #     configure :current_sign_in_ip, :string 
  #     configure :last_sign_in_ip, :string 
  #     configure :subscribed, :boolean 
  #     configure :moderator_segment, :integer 
  #     configure :search_term_topic_id, :integer         # Hidden 
  #     configure :authentication_token, :string 
  #     configure :communication_preference, :integer 
  #     configure :last_email_request_at, :datetime 
  #     configure :last_followback_failure, :datetime 
  #     configure :subject, :string 

  #   # Cross-section configuration:

  #     # object_label_method :name     # Name of the method called for pretty printing an *instance* of ModelName
  #     # label 'My model'              # Name of ModelName (smartly defaults to ActiveRecord's I18n API)
  #     # label_plural 'My models'      # Same, plural
  #     # weight 0                      # Navigation priority. Bigger is higher.
  #     # parent OtherModel             # Set parent model for navigation. MyModel will be nested below. OtherModel will be on first position of the dropdown
  #     # navigation_label              # Sets dropdown entry's name in navigation. Only for parents!

  #   # Section specific configuration:

  #     list do
  #       # filters [:id, :name]  # Array of field names which filters should be shown by default in the table header
  #       # items_per_page 100    # Override default_items_per_page
  #       # sort_by :id           # Sort column (default is primary key)
  #       # sort_reverse true     # Sort direction (default is true for primary key, last created first)
  #     end
  #     show do; end
  #     edit do; end
  #     export do; end
  #     # also see the create, update, modal and nested sections, which override edit in specific cases (resp. when creating, updating, modifying from another model in a popup modal or modifying from another model nested form)
  #     # you can override a cross-section field configuration in any section with the same syntax `configure :field_name do ... end`
  #     # using `field` instead of `configure` will exclude all other fields and force the ordering
  # end

end
