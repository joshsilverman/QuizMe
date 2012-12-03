Quizmemanager::Application.routes.draw do
  
  get "badges/load"  
  get "badges/issuable"
  post "badges/issue"  
  resources :badges

  get "feeds/index"
  match "feeds/index(/:post_id(/:answer_id))" => "feeds#index"
  match "feeds/:id/scores" => "feeds#scores"
  match "feeds/:id/more/:last_post_id" => "feeds#more"
  match "feeds/:id/manage" => "feeds#manage"
  match "askers/:id/hide_all/:post_ids" => "askers#hide_all"
  match "feeds/:id(/:post_id(/:answer_id))" => "feeds#show"

  match "/ask" => "feeds#ask"
  match "/respond_to_question" => "feeds#respond_to_question"
  match "/manager_response" => "feeds#manager_response"
  match "/link_to_post" => "feeds#link_to_post"
  match "/create_split_test" => "feeds#create_split_test"
  match "/trigger_split_test" => "feeds#trigger_split_test"

  match "/dashboard" => "askers#dashboard"
  match "/dashboard/core_by_handle/:asker_id" => "askers#get_core_by_handle"
  match "/get_detailed_metrics" => 'askers#get_detailed_metrics'
  match "/get_handle_metrics" => 'askers#get_handle_metrics'
  match "/posts/:id/refer" => "posts#refer"

  post "posts/update_engagement_type"
  post "posts/update"
  post "posts/respond_to_post"
  post "posts/retweet"

  match "questions/enqueue/:asker_id/:question_id" => "questions#enqueue"
  match "questions/dequeue/:asker_id/:question_id" => "questions#dequeue"

  match "questions/asker/:asker_id" => "questions#index"
  post "questions/save_question_and_answers"
  match "questions/:id/:slug" => "questions#show"
  match "questions/new/:asker_id" => "questions#new"
  match "/moderate" => "questions#moderate"
  match "/moderate/update" => "questions#moderate_update"
  match "/answers/:question_id" => "questions#display_answers"

  resources :questions

  scope :constraints => { :protocol => "https" } do
    match "/answers/:question_id" => "questions#display_answers"
  end

  match 'auth/:provider/callback' => 'sessions#create'
  match "/signout" => "sessions#destroy", :as => :signout
  match "/confirm_js" => "sessions#confirm_js"

  match 'questions/import_data_from_qmm' => 'questions#import_data_from_qmm'
  match '/stats' => 'accounts#stats'

  match '/get_shortened_link' => 'posts#get_shortened_link'

  resources :askers
  match "users/:id" => "askers#update"

  match "clients/:id/report" => "clients#report"

  resources :rate_sheets
  resources :users
  resources :posts
  resources :mentions
  
  #Split Dashboard
  mount Split::Dashboard, :at => 'split'

  root :to => 'feeds#index'

  #catch user profiles
  get ":twi_screen_name" => "users#show"
  get ":twi_screen_name/badges" => "users#badges"
  get ":twi_screen_name/badges/:badge_title" => "users#badges"
  get ":twi_screen_name/badges/story/:badge_title" => "users#badges"

end
