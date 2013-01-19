Quizmemanager::Application.routes.draw do
  
  get "answer/new"
  get "answer/create"
  get "answer/update"
  get "answer/edit"
  get "answer/destroy"
  get "answer/index"
  get "answer/show"

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
  match "/activity_stream" => "feeds#activity_stream"

  match "/ask" => "feeds#ask"
  match "/respond_to_question" => "feeds#respond_to_question"
  match "/manager_response" => "feeds#manager_response"
  match "/manager_post" => "feeds#manager_post"
  match "/link_to_post" => "feeds#link_to_post"
  match "/create_split_test" => "feeds#create_split_test"
  match "/trigger_split_test" => "feeds#trigger_split_test"

  match "/dashboard" => "askers#dashboard"
  match "/dashboard/core_by_handle/:asker_id" => "askers#get_core_by_handle"
  match "/get_detailed_metrics" => 'askers#get_detailed_metrics'
  match "/graph/:party/:graph" => 'askers#graph'
  match "/get_retention_metrics" => 'askers#get_retention_metrics'
  match "/posts/:publication_id/refer" => "posts#refer"

  post "posts/update"
  post "posts/respond_to_post"
  post "posts/retweet"
  match "/posts/mark_ugc" => "posts#mark_ugc"

  match "questions/enqueue/:asker_id/:question_id" => "questions#enqueue"
  match "questions/dequeue/:asker_id/:question_id" => "questions#dequeue"

  match "/questions/answers/:question_id" => "questions#display_answers"
  # match "/questions/answers/:question_id" => "questions#display_answers", :constraints => { :protocol => "https" }
  # match "/questions/answers(/*path)", :to => redirect { |_, request|
    # "https://" + request.host_with_port + request.fullpath }

  match "questions/asker/:asker_id" => "questions#index"
  match "questions/asker/:asker_id/import" => "questions#import"
  post "questions/save_question_and_answers"
  match "questions/:id/:slug" => "questions#show"
  match "questions/new/:asker_id" => "questions#new"
  match "/moderate" => "questions#moderate"
  match "/moderate/update" => "questions#moderate_update"

  match "/newsletter" => "users#newsletter"

  resources :questions
  resources :answers


  match 'auth/:provider/callback' => 'sessions#create'
  match "/signout" => "sessions#destroy", :as => :signout
  match "/confirm_js" => "sessions#confirm_js"

  match 'questions/import_data_from_qmm' => 'questions#import_data_from_qmm'
  match '/stats' => 'accounts#stats'

  resources :askers
  get "users/supporters" => "users#supporters"

  match "clients/:id/report" => "clients#report"
  post "clients/nudge" => "clients#nudge"

  resources :rate_sheets
  resources :users
  resources :posts
  resources :mentions
  
  #Split Dashboard
  mount Split::Dashboard, :at => 'split'
  Split::Dashboard.use Rack::Auth::Basic do |username, password|
    username == 'wisr' && password == 'WrWr@ppl3'
  end  

  root :to => 'feeds#index'

  #catch user profiles
  get ":twi_screen_name" => "users#show"
  get ":twi_screen_name/badges" => "users#badges"
  get ":twi_screen_name/badges/:badge_title" => "users#badges"
  get ":twi_screen_name/badges/story/:badge_title" => "users#badges"

end
