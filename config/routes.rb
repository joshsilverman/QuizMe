Quizmemanager::Application.routes.draw do
  
  get "feeds/index"
  match "feeds/:id/scores" => "feeds#scores"
  match "feeds/:id/more/:last_post_id" => "feeds#more"
  match "feeds/:id/manage" => "feeds#manage"
  match "feeds/:id(/:post_id(/:answer_id))" => "feeds#show"
  match "/respond_to_question" => "feeds#respond_to_question"
  match "/manager_response" => "feeds#manager_response"
  match "/link_to_post" => "feeds#link_to_post"
  match "/get_abingo_dm_response" => "feeds#get_abingo_dm_response"
  match "/dashboard" => "askers#dashboard"
  match "/posts/:id/refer" => "posts#refer"

  post "posts/update_engagement_type"
  post "posts/update"
  post "posts/respond_to_post"
  post "questions/save_question_and_answers"
  match "questions/new/:asker_id" => "questions#new"
  match "/moderate" => "questions#moderate"
  match "/moderate/update" => "questions#moderate_update"
  match 'auth/:provider/callback' => 'sessions#create'
  match "/signout" => "sessions#destroy", :as => :signout

  match 'questions/import_data_from_qmm' => 'questions#import_data_from_qmm'
  match '/stats' => 'accounts#stats'

  match "users/:id" => "askers#update"
  resources :askers

  resources :users
  resources :questions
  resources :posts
  resources :mentions
  
  #abingo
  match 'abingo(/:action(/:id))', :to => 'abingo_dashboard', :as => :bingo

  root :to => 'feeds#index'
end
