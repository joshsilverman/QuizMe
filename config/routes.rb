Quizmemanager::Application.routes.draw do
  
  get "feeds/index"
  match "feeds/:id/scores" => "feeds#scores"
  match "feeds/:id/more/:last_post_id" => "feeds#more"
  match "feeds/:id/manage" => "feeds#manage"
  match "feeds/:id(/:post_id(/:answer_id))" => "feeds#show"
  match "/respond_to_question" => "feeds#respond_to_question"
  match "/manager_response" => "feeds#manager_response"
  match "/link_to_post" => "feeds#link_to_post"
  match "/create_split_test" => "feeds#create_split_test"
  match "/trigger_split_test" => "feeds#trigger_split_test"
  match "/dashboard" => "askers#dashboard"
  match "/posts/:id/refer" => "posts#refer"

  post "posts/update_engagement_type"
  post "posts/update"
  post "posts/respond_to_post"
  post "questions/save_question_and_answers"
  match "questions/:id/:slug" => "questions#show"
  match "questions/new/:asker_id" => "questions#new"
  match "/moderate" => "questions#moderate"
  match "/moderate/update" => "questions#moderate_update"
  match 'auth/:provider/callback' => 'sessions#create'
  match "/signout" => "sessions#destroy", :as => :signout
  match "/confirm_js" => "sessions#confirm_js"

  match 'questions/import_data_from_qmm' => 'questions#import_data_from_qmm'
  match '/stats' => 'accounts#stats'

  match '/get_shortened_link' => 'posts#get_shortened_link'

  match "users/:id" => "askers#update"
  resources :askers

  match "clients/:id/report" => "clients#report"

  resources :users
  resources :questions
  resources :posts
  resources :mentions
  
  #Split Dashboard
  mount Split::Dashboard, :at => 'split'

  root :to => 'feeds#index'
end
