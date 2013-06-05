Quizmemanager::Application.routes.draw do
  
  # temporarily disallow basic auth
  match "/users/sign_up" => redirect("/")
  match "/users/sign_in" => redirect("/")
  
  devise_for :users, :controllers => { :omniauth_callbacks => "authorizations" }

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
  match "feeds/manage" => "feeds#manage"

  resource :moderations
  get "moderations/manage"

  match "feeds/stream" => "feeds#stream"
  
  match "askers/:id/hide_all/:post_ids" => "askers#hide_all"
  match "askers/:id/import" => "askers#import"

  post "feeds/search"
  match "feeds/:id(/:post_id(/:answer_id))" => "feeds#show"
  match "u/feeds/:id(/:post_id(/:answer_id))" => "feeds#unauth_show"

  match '/search' => 'feeds#index_with_search'


  match "/ask" => "feeds#ask"
  match "/respond_to_question" => "feeds#respond_to_question"
  match "/manager_response" => "feeds#manager_response"
  match "/manager_post" => "feeds#manager_post"
  post '/refer_a_friend' => 'feeds#refer_a_friend'
  match "/link_to_post" => "feeds#link_to_post"
  match "/create_split_test" => "feeds#create_split_test"
  match "/trigger_split_test" => "feeds#trigger_split_test"

  match "/dashboard" => "askers#dashboard"
  match "/dashboard/core" => "askers#get_core_metrics"
  match "/get_detailed_metrics" => 'askers#get_detailed_metrics'
  match "/graph/:party/:graph" => 'askers#graph'
  match "/get_retention_metrics" => 'askers#get_retention_metrics'
  get "experiments" => 'experiments#index'
  get "experiments/index_concluded"
  post "experiments/conclude" => 'experiments#conclude'
  post "experiments/show"
  post "experiments/trigger" => 'experiments#trigger'
  post "experiments/reset" => 'experiments#reset'
  post "experiments/delete" => 'experiments#destroy'

  match "/posts/:publication_id/refer" => "posts#refer"
  match "/nudge/:id/:user_id/:asker_id" => "posts#nudge_redirect"

  post "posts/update"
  post "posts/respond_to_post"
  post "posts/retweet"
  post "posts/manager_retweet"
  match "/posts/mark_ugc" => "posts#mark_ugc"
  match "/posts/toggle_tag" => "posts#toggle_tag"

  match "questions/enqueue/:asker_id/:question_id" => "questions#enqueue"
  match "questions/dequeue/:asker_id/:question_id" => "questions#dequeue"

  match "/questions/answers/:question_id" => "questions#display_answers"
  # match "/questions/answers/:question_id" => "questions#display_answers", :constraints => { :protocol => "https" }
  # match "/questions/answers(/*path)", :to => redirect { |_, request|
    # "https://" + request.host_with_port + request.fullpath }

  match "questions/asker/:asker_id" => "questions#index"
  match "questions/asker/:asker_id/import" => "questions#import"
  post "questions/save_question_and_answers"
  match "questions/:id" => "questions#show"
  match "questions/:id/:slug" => "questions#show"
  match "questions/new/:asker_id" => "questions#new"
  match "/moderate" => "questions#moderate"
  match "/moderate/update" => "questions#moderate_update"

  match "/tags" => 'posts#tags'

  match "/newsletter" => "users#newsletter"
  match '/progress_report' => 'users#progress_report'

  resources :questions
  resources :answers

  # match 'auth/:provider/callback' => 'services#create'
  # resources :services, :only => [:index, :create, :destroy]

  # match "/signout" => "sessions#destroy", :as => :signout
  match "/confirm_js" => "sessions#confirm_js"

  match 'questions/import_data_from_qmm' => 'questions#import_data_from_qmm'
  match '/stats' => 'accounts#stats'
  
  get '/askers/edit_graph' => 'askers#edit_graph'
  post '/askers/add_related' => 'askers#add_related'
  post '/askers/remove_related' => 'askers#remove_related'

  get '/users/:id/activity' => 'users#activity'
  get "users/supporters" => "users#supporters"
  post "users/supporters" => "users#create_supporter"
  delete "users/:id" => "users#destroy_supporter"
  get "/user/supporters/:id/touch" => "users#touch_supporter"
  get '/users/activity_feed'

  match '/users/:id/unsubscribe' => 'users#unsubscribe_form'
  post '/unsubscribe' => 'users#unsubscribe'
  # match '/users/:id/questions/:asker_id' => 'users#asker_questions'
  # match '/users/:id/questions' => 'users#questions'
  match '/askers/:id/questions' => 'askers#questions'

  match "clients/:id/report" => "clients#report"
  post "clients/nudge" => "clients#nudge"

  post '/askers/nudge' => 'askers#send_nudge'

  match '/tutor' => 'askers#tutor'

  resources :rate_sheets
  resources :users
  resources :posts
  resources :mentions
  resources :exams
  resources :askers

  root :to => 'feeds#index'

  #catch user profiles
  get ":twi_screen_name" => "users#show"
  get ":twi_screen_name/badges" => "users#badges"
  get ":twi_screen_name/badges/:badge_title" => "users#badges"
  get ":twi_screen_name/badges/story/:badge_title" => "users#badges"

end
