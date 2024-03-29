Quizmemanager::Application.routes.draw do


  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  constraints subdomain: false do
    if Rails.env.production?
      get ':any', to: redirect(subdomain: 'www', path: '/%{any}'), any: /.*/
    end
  end

  devise_for :users, :controllers => { :omniauth_callbacks => "authorizations", sessions: :sessions, registrations: :registrations }
  devise_scope :user do
    get 'users/sign_out' => 'sessions#destroy'
  end

  resources :askers, except: [:destroy] do
    collection do
      get :recent
    end
  end

  get '/askers/:id/questions(/:user_id)' => 'askers#questions'

  resources :users, only: [:correct_question_ids, :register_device_token, :me] do
    get :correct_question_ids

    collection do
      get :wisr_follow_ids
      get :auth_token
      post :register_device_token
      get :me
    end

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

  resources :topics, only: [:index, :show] do
    collection do
      get :answered_counts
    end
  end
  get ':subject/:name/quiz' => 'topics#show'

  resources :lessons, only: [:create, :show, :update]

  resources :relationships, only: [:create] do
    collection do
      post 'deactivate'
    end
  end

  resources :posts do
    collection do
      get 'recent_reengage_inactive'
    end
  end

  resources :publications, only: [:show]

  resources :variants, only: [:current] do
    collection do
      get 'current'
    end
  end

  resources :ratings, only: [:create, :index]

  get "/nudge/:id/:user_id/:asker_id" => "posts#nudge_redirect"
  get "/posts/:publication_id/refer" => "posts#refer"
  post "posts/respond_to_post"
  post "posts/retweet"

  get '/users/:id/activity' => 'users#activity'
  get '/users/activity_feed'
  get '/users/:id/unsubscribe' => 'users#unsubscribe_form'
  post '/unsubscribe' => 'users#unsubscribe'
  get '/progress_report' => 'users#progress_report'

  resources :issuances, only: [:show, :index]


  resource :moderations
  get "moderations/manage"

  get "/ask" => "feeds#ask"
  post "/respond_to_question" => "feeds#respond_to_question"
  post "/manager_post" => "feeds#manager_post"

  get "/dashboard" => "askers#dashboard"
  get "/dashboard/core" => "askers#get_core_metrics"
  get "/get_detailed_metrics" => 'askers#get_detailed_metrics'
  get "/graph/:party/:graph" => 'askers#graph'
  get "/get_retention_metrics" => 'askers#get_retention_metrics'

  resources :questions
  resources :answers, only: [:create, :update, :destroy]
  post "questions/save_question_and_answers"
  post 'questions/update_question_and_answers'
  get "questions/:id" => "questions#show"
  get "questions/:id/:slug" => "questions#show"

  get "/moderate" => "questions#moderate"
  post "/moderate/update" => "questions#moderate_update"

  get '/sitemap' => 'pages#sitemap'

  post "/email_askers/save_private_response"

  get "feeds/index"
  get "feeds/index(/:post_id(/:answer_id))" => "feeds#index"
  get "feeds/:id/more/:last_post_id" => "feeds#more"
  get "feeds/stream" => "feeds#stream"
  get "feeds/:id(/:publication_id(/:answer_id))" => "feeds#show"

  get "u/feeds/:id(/:publication_id(/:answer_id))" => "feeds#show" # @deprecated route
  get "index" => "feeds#index"
  get ":subject/new" => "feeds#new"
  get ":subject(/:publication_id(/:answer_id))" => "feeds#show"


  root :to => 'feeds#index'
end
