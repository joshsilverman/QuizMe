Quizmemanager::Application.routes.draw do
  resources :accounts
  resources :users
  resources :questions
  resources :posts
  resources :mentions
  
  get "feeds/index"

  match "feeds/:id/scores" => "feeds#scores"
  match "feeds/:id/more/:last_post_id" => "feeds#more"
  match "feeds/:id" => "feeds#show"

  post "mentions/update"
  post "questions/save_question_and_answers"
  match "questions/new/:account_id" => "questions#new"
  match "/moderate" => "questions#moderate"
  match 'auth/:provider/callback' => 'sessions#create'
  match "/signout" => "sessions#destroy", :as => :signout

  match 'questions/import_data_from_qmm' => 'questions#import_data_from_qmm'



  root :to => 'feeds#index'
end
