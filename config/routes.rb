Quizmemanager::Application.routes.draw do
  # temporarily disallow basic auth
  get "/users/sign_up" => redirect("/")
  get "/users/sign_in" => redirect("/")
  
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
  get "feeds/index(/:post_id(/:answer_id))" => "feeds#index"
  get "feeds/:id/scores" => "feeds#scores"
  get "feeds/:id/more/:last_post_id" => "feeds#more"
  get "feeds/:id/manage" => "feeds#manage"
  get "feeds/manage" => "feeds#manage"

  resource :moderations
  get "moderations/manage"

  get "feeds/stream" => "feeds#stream"
  
  get "askers/:id/hide_all/:post_ids" => "askers#hide_all"

  post "feeds/search"
  get "feeds/:id(/:post_id(/:answer_id))" => "feeds#show"
  get "u/feeds/:id(/:post_id(/:answer_id))" => "feeds#show" # @deprecated route

  get '/search' => 'feeds#index_with_search'

  get "/ask" => "feeds#ask"
  post "/respond_to_question" => "feeds#respond_to_question"
  post "/manager_response" => "feeds#manager_response"
  post "/manager_post" => "feeds#manager_post"
  post '/refer_a_friend' => 'feeds#refer_a_friend'
  post "/link_to_post" => "feeds#link_to_post"
  post "/create_split_test" => "feeds#create_split_test"
  post "/trigger_split_test" => "feeds#trigger_split_test"

  get "/dashboard" => "askers#dashboard"
  get "/dashboard/core" => "askers#get_core_metrics"
  get "/get_detailed_metrics" => 'askers#get_detailed_metrics'
  get "/graph/:party/:graph" => 'askers#graph'
  get "/get_retention_metrics" => 'askers#get_retention_metrics'
  get "experiments" => 'experiments#index'
  get "experiments/index_concluded"
  get '/experiments/index_search_terms'
  get '/experiments/index_concluded_search_terms'
  post "experiments/conclude" => 'experiments#conclude'
  post "experiments/show"
  post "experiments/trigger" => 'experiments#trigger'
  post "experiments/reset" => 'experiments#reset'
  post "experiments/delete" => 'experiments#destroy'

  get "/posts/:publication_id/refer" => "posts#refer"
  get "/nudge/:id/:user_id/:asker_id" => "posts#nudge_redirect"

  post "posts/update"
  post "posts/respond_to_post"
  post "posts/retweet"
  post "posts/manager_retweet"
  post "/posts/mark_ugc" => "posts#mark_ugc"
  post "/posts/toggle_tag" => "posts#toggle_tag"

  get "questions/enqueue/:asker_id/:question_id" => "questions#enqueue"
  get "questions/dequeue/:asker_id/:question_id" => "questions#dequeue"

  get "/questions/answers/:question_id" => "questions#display_answers"

  get "questions/manage" => "questions#manage"
  get "questions/asker/:asker_id" => "questions#index"

  post "questions/save_question_and_answers"
  post 'questions/update_question_and_answers'
  get "questions/:id" => "questions#show"
  get "questions/:id/:slug" => "questions#show"
  get "questions/new/:asker_id" => "questions#new"
  get "/moderate" => "questions#moderate"
  post "/moderate/update" => "questions#moderate_update"

  get "/tags" => 'posts#tags'

  # get "/newsletter" => "users#newsletter"
  get '/progress_report' => 'users#progress_report'

  resources :questions
  resources :answers

  get "/confirm_js" => "sessions#confirm_js"

  get '/sitemap' => 'pages#sitemap'
  
  get '/askers/edit_graph' => 'askers#edit_graph'
  post '/askers/add_related' => 'askers#add_related'
  post '/askers/remove_related' => 'askers#remove_related'

  get '/users/:id/activity' => 'users#activity'
  get "users/supporters" => "users#supporters"
  post "users/supporters" => "users#create_supporter"
  delete "users/:id" => "users#destroy_supporter"
  get "/user/supporters/:id/touch" => "users#touch_supporter"
  get '/users/activity_feed'
  post '/users/add_email'

  get '/users/:id/unsubscribe' => 'users#unsubscribe_form'
  post '/unsubscribe' => 'users#unsubscribe'
  get '/askers/:id/questions(/:user_id)' => 'askers#questions'

  post '/askers/nudge' => 'askers#send_nudge'
  post "/email_askers/save_private_response"

  resources :users
  resources :posts
  resources :mentions
  resources :exams
  resources :askers, except: [:show]

  root :to => 'feeds#index'
end