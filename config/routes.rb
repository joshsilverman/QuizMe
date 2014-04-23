Quizmemanager::Application.routes.draw do
  
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  get "/users/sign_up" => redirect("/")
  get "/users/sign_in" => redirect("/")
  
  devise_for :users, :controllers => { :omniauth_callbacks => "authorizations" }

  resources :askers, except: [:destroy] do
    collection do
      get :recent
    end
  end

  get '/askers/:id/questions(/:user_id)' => 'askers#questions'

  resources :users, only: [:correct_question_ids] do
    get :correct_question_ids

    resources :posts, only: [:answer_count] do
      collection do
        get :answer_count
      end
    end

    resources :moderations, only: [:count] do
      collection do
        get :count
      end
    end

    resources :questions, only: [:count] do
      collection do
        get :count
      end
    end
  end

  resources :topics, only: [:index]
  get ':subject/:name/quiz' => 'topics#show'

  get '/users/:id/activity' => 'users#activity'
  get '/users/activity_feed'
  get '/users/:id/unsubscribe' => 'users#unsubscribe_form'
  
  post '/unsubscribe' => 'users#unsubscribe'
  get '/progress_report' => 'users#progress_report'

  resources :issuances, only: [:show, :index]

  resources :answers
  get "answer/new"
  get "answer/create"
  get "answer/update"
  get "answer/edit"
  get "answer/destroy"
  get "answer/index"
  get "answer/show"


  resource :moderations
  get "moderations/manage"

  get "/ask" => "feeds#ask"
  post "/respond_to_question" => "feeds#respond_to_question"
  post "/manager_post" => "feeds#manager_post"
  post "/create_split_test" => "feeds#create_split_test"
  post "/trigger_split_test" => "feeds#trigger_split_test"

  get "/dashboard" => "askers#dashboard"
  get "/dashboard/core" => "askers#get_core_metrics"
  get "/get_detailed_metrics" => 'askers#get_detailed_metrics'
  get "/graph/:party/:graph" => 'askers#graph'
  get "/get_retention_metrics" => 'askers#get_retention_metrics'

  get "/posts/:publication_id/refer" => "posts#refer"
  get "/nudge/:id/:user_id/:asker_id" => "posts#nudge_redirect"

  post "posts/respond_to_post"
  post "posts/retweet"

  get "/questions/answers/:question_id" => "questions#display_answers"

  get "questions/asker/:asker_id" => "questions#index"

  resources :questions
  post "questions/save_question_and_answers"
  post 'questions/update_question_and_answers'
  get "questions/:id" => "questions#show"
  get "questions/:id/:slug" => "questions#show"
  get "questions/new/:asker_id" => "questions#new"

  get "/moderate" => "questions#moderate"
  post "/moderate/update" => "questions#moderate_update"

  get "/confirm_js" => "sessions#confirm_js"
  get '/sitemap' => 'pages#sitemap'

  post "/email_askers/save_private_response"

  resources :posts
  resources :mentions

  get "feeds/index"
  get "feeds/index(/:post_id(/:answer_id))" => "feeds#index"
  get "feeds/:id/more/:last_post_id" => "feeds#more"
  get "feeds/stream" => "feeds#stream"
  get "feeds/:id(/:publication_id(/:answer_id))" => "feeds#show"

  get "u/feeds/:id(/:publication_id(/:answer_id))" => "feeds#show" # @deprecated route
  get ":subject(/:publication_id(/:answer_id))" => "feeds#show"

  root :to => 'feeds#index'
end