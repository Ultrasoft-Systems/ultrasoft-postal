# frozen_string_literal: true

Rails.application.routes.draw do
  # ───────────────────────────────────────────────────────────────────────────
  # Legacy API v1 Routes
  # ───────────────────────────────────────────────────────────────────────────
  match "/api/v1/send/message" => "legacy_api/send#message", via: [:get, :post, :patch, :put]
  match "/api/v1/send/raw" => "legacy_api/send#raw", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/message" => "legacy_api/messages#message", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/deliveries" => "legacy_api/messages#deliveries", via: [:get, :post, :patch, :put]

  # ───────────────────────────────────────────────────────────────────────────
  # RESTful API v2 Routes
  # ───────────────────────────────────────────────────────────────────────────
  namespace :api do
    namespace :v2 do
      # Auth / API token management
      resources :api_tokens, path: "auth/tokens", only: [:index, :create, :destroy]

      # Organizations
      resources :organizations, param: :permalink, only: [:index, :show, :create, :update, :destroy] do
        member do
          get :domains
        end
        resources :users, only: [:index, :create, :destroy], controller: "organization_users"
        resources :domains, param: :uuid, only: [:destroy], controller: "organization_domains"
      end

      # Servers — scoped under organizations
      scope "org/:org_permalink" do
        resources :servers, param: :permalink, only: [:index, :show, :create, :update, :destroy] do
          member do
            post :suspend
            post :unsuspend
            get :queue
            get :limits
            get :stats
          end

          resources :domains, param: :uuid, only: [:index, :show, :create, :destroy] do
            member do
              post :verify
              post :check_dns
            end
          end

          resources :credentials, param: :uuid, only: [:index, :show, :create, :update, :destroy]

          resources :routes, param: :uuid, only: [:index, :show, :create, :update, :destroy]

          namespace :endpoints do
            resources :smtp, param: :uuid, only: [:index, :show, :create, :update, :destroy],
                      controller: "smtp"
            resources :http, param: :uuid, only: [:index, :show, :create, :update, :destroy],
                      controller: "http"
            resources :address, param: :uuid, only: [:index, :show, :create, :update, :destroy],
                      controller: "address"
          end

          resources :webhooks, param: :uuid, only: [:index, :show, :create, :update, :destroy] do
            member do
              get :history
              post "retry/:request_uuid", action: :retry_request, as: :retry_request
            end
          end

          resources :ip_pool_rules, param: :uuid, only: [:index, :create, :update, :destroy]

          resources :track_domains, param: :uuid, only: [:index, :create, :update, :destroy] do
            member do
              post :toggle_ssl
              post :check
            end
          end
        end
      end

      # Messages — server resolved from auth scope
      scope "messages" do
        get "outgoing", to: "messages#outgoing"
        get "incoming", to: "messages#incoming"
        get "held", to: "messages#held"
        get "suppressions", to: "messages#suppressions"
        get ":id", to: "messages#show"
        get ":id/deliveries", to: "messages#deliveries"
        get ":id/attachments", to: "messages#attachments"
        get ":id/attachment/:filename", to: "messages#attachment", as: :message_attachment
        get ":id/plain", to: "messages#plain"
        get ":id/html", to: "messages#html"
        get ":id/headers", to: "messages#headers"
        get ":id/activity", to: "messages#activity"
        get ":id/spam_checks", to: "messages#spam_checks"
        post ":id/retry", to: "messages#retry"
        post ":id/cancel_hold", to: "messages#cancel_hold"
        delete ":id", to: "messages#destroy"
      end

      # Send
      post "send/message", to: "send#message"
      post "send/raw", to: "send#raw"

      # Suppressions — server resolved from auth scope
      resources :suppressions, only: [:index, :create, :destroy]

      # Statistics
      get "stats/server/:org_permalink/:server_permalink", to: "stats#server", as: :server_stats
      get "stats/organization/:org_permalink", to: "stats#organization", as: :organization_stats

      # IP Pools (admin only)
      resources :ip_pools, only: [:index, :show, :create, :update, :destroy] do
        resources :ip_addresses, param: :uuid, only: [:index, :create, :update, :destroy]
      end

      # Users (admin only)
      resources :users, param: :uuid, only: [:index, :show, :create, :update, :destroy]
      post "users/invite", to: "users#invite"
    end
  end

  scope "org/:org_permalink", as: "organization" do
    resources :domains, only: [:index, :new, :create, :destroy] do
      match :verify, on: :member, via: [:get, :post]
      get :setup, on: :member
      post :check, on: :member
    end
    resources :servers, except: [:index] do
      resources :domains, only: [:index, :new, :create, :destroy] do
        match :verify, on: :member, via: [:get, :post]
        get :setup, on: :member
        post :check, on: :member
      end
      resources :track_domains do
        post :toggle_ssl, on: :member
        post :check, on: :member
      end
      resources :credentials
      resources :routes
      resources :http_endpoints
      resources :smtp_endpoints
      resources :address_endpoints
      resources :ip_pool_rules
      resources :messages do
        get :incoming, on: :collection
        get :outgoing, on: :collection
        get :held, on: :collection
        get :activity, on: :member
        get :plain, on: :member
        get :html, on: :member
        get :html_raw, on: :member
        get :attachments, on: :member
        get :headers, on: :member
        get :attachment, on: :member
        get :download, on: :member
        get :spam_checks, on: :member
        post :retry, on: :member
        post :cancel_hold, on: :member
        get :suppressions, on: :collection
        delete :remove_from_queue, on: :member
        get :deliveries, on: :member
      end
      resources :webhooks do
        get :history, on: :collection
        get "history/:uuid", on: :collection, action: "history_request", as: "history_request"
      end
      get :limits, on: :member
      get :retention, on: :member
      get :queue, on: :member
      get :spam, on: :member
      get :delete, on: :member
      get "help/outgoing" => "help#outgoing"
      get "help/incoming" => "help#incoming"
      get :advanced, on: :member
      post :suspend, on: :member
      post :unsuspend, on: :member
    end

    resources :ip_pool_rules
    resources :ip_pools, controller: "organization_ip_pools" do
      put :assignments, on: :collection
    end
    root "servers#index"
    get "settings" => "organizations#edit"
    patch "settings" => "organizations#update"
    get "delete" => "organizations#delete"
    delete "delete" => "organizations#destroy"
  end

  resources :organizations, except: [:index]
  resources :users
  resources :ip_pools do
    resources :ip_addresses
  end

  get "settings" => "user#edit"
  patch "settings" => "user#update"
  post "persist" => "sessions#persist"

  get "login" => "sessions#new"
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy"
  match "login/reset" => "sessions#begin_password_reset", :via => [:get, :post]
  match "login/reset/:token" => "sessions#finish_password_reset", :via => [:get, :post]

  if Postal::Config.oidc.enabled?
    get "auth/oidc/callback", to: "sessions#create_from_oidc"
  end

  get ".well-known/jwks.json" => "well_known#jwks"

  get "ip" => "sessions#ip"

  root "organizations#index"
end
