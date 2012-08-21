Quizmemanager::Application.routes.draw do
  resources :users
  resources :questions
  resources :posts
  resources :mentions
  resources :askers
  
  get "feeds/index"
  match "feeds/:id/scores" => "feeds#scores"
  match "feeds/:id/more/:last_post_id" => "feeds#more"
  match "feeds/:id(/:post_id(/:answer_id))" => "feeds#show"
  match "/respond" => "feeds#respond"

  post "posts/update"
  post "posts/response"
  post "questions/save_question_and_answers"
  match "questions/new/:account_id" => "questions#new"
  match "/moderate" => "questions#moderate"
  match "/moderate/update" => "questions#moderate_update"
  match 'auth/:provider/callback' => 'sessions#create'
  match "/signout" => "sessions#destroy", :as => :signout

  match 'questions/import_data_from_qmm' => 'questions#import_data_from_qmm'
  match '/stats' => 'accounts#stats'

  root :to => 'feeds#index'
end
