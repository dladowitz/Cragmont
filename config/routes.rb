Rails.application.routes.draw do
  root "home#index"

  resource :registration, only: %i[new create]
  resource :session, only: %i[new create destroy]

  resources :trips, only: %i[index show] do
    resource :trip_signup, only: :create
  end

  namespace :admin do
    root "dashboard#index"
    resources :users
    resources :campgrounds
    resources :trips do
      resources :campsites, except: %i[index show]
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
