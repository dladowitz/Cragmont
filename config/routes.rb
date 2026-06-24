Rails.application.routes.draw do
  root "home#index"

  if Rails.env.development? || Rails.env.staging?
    letter_opener_access = lambda do |request|
      Rails.env.development? || User.find_by(id: request.session[:user_id])&.super_admin?
    end

    constraints letter_opener_access do
      mount LetterOpenerWeb::Engine, at: "/admin/letter_opener"
    end
  end

  resource :registration, only: %i[new create]
  resource :session, only: %i[new create destroy]
  resources :password_resets, only: %i[new create edit update], param: :token
  get "waiver_requests/:token", to: "waiver_requests#new", as: :waiver_request
  post "waiver_requests/:token", to: "waiver_requests#create"
  resource :profile, only: %i[show edit update destroy] do
    resource :waiver, only: %i[new create], controller: "profile_waivers"
  end
  get "help", to: "help_requests#new", as: :new_help_request
  post "help", to: "help_requests#create", as: :create_help_request
  resources :help_requests, only: %i[index show] do
    post :reply, on: :member
  end
  post "stripe/webhooks", to: "stripe_webhooks#create"
  get "payment_requests/:token", to: "trip_payment_requests#show", as: :trip_payment_request

  resources :trips, only: %i[index show] do
    get "what-to-expect", on: :collection
    post "guest_waiver_emails/:id", to: "guest_waiver_emails#create", as: :guest_waiver_email
    resources :campsites, only: [] do
      resource :campsite_signup, only: %i[create destroy] do
        patch :guest_password
        patch :participant_password
      end
    end
  end

  namespace :admin do
    root to: redirect("/admin/trips")
    resource :settings, only: %i[show update]
    resources :content_pages, param: :slug, only: %i[edit update] do
      post :preview, on: :collection
    end
    resources :help_requests, only: %i[index show] do
      post :reply, on: :member
      patch :resolve, on: :member
    end
    resources :help_notification_subscribers, only: %i[index create destroy]
    resources :users do
      post :email_waiver_request, on: :member
    end
    resources :campgrounds
    resources :trips do
      patch :restore, on: :member
      get "readiness", to: "trip_readiness#show", as: :readiness, on: :member
      get "post_trip", to: "trip_post_trip#show", as: :post_trip, on: :member
      patch "readiness/:task_key", to: "trip_readiness#update", as: :readiness_task, on: :member
      resources :transactions, only: :index, controller: "trip_transactions" do
        post :refund, on: :member
      end
      resources :campsites, except: %i[index show] do
        patch :record_registration_reimbursement, on: :member
      end
      resources :campsite_signups, only: %i[create] do
        patch :make_waitlist_eligible, on: :member
        patch :revoke_waitlist_eligibility, on: :member
        patch :move_to_campsite, on: :member
        patch :move_to_waitlist, on: :member
        patch :update_parking_status, on: :member
        post :email_participant_link, on: :member
        delete :remove_from_campsite, on: :member
        delete :remove_from_waitlist, on: :member
      end
      resources :trip_payment_requests, only: %i[create] do
        post :email, on: :member
        patch :cancel, on: :member
      end
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  match "/404", to: "errors#not_found", via: :all

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
