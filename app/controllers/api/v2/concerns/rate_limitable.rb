# frozen_string_literal: true

module API
  module V2
    module Concerns
      # Rate limiting concern for API v2 controllers.
      #
      # Provides per-token and per-IP rate limiting using Rails.cache as the
      # backing store. Limits are configurable per-endpoint category:
      #
      #   Category      | Window | Max Requests | Burst
      #   --------------|--------|-------------|------
      #   :default       | 60s    | 120          | 150
      #   :send          | 60s    | 30           | 50
      #   :auth          | 60s    | 20           | 30
      #   :admin         | 60s    | 60           | 80
      #
      # Rate limit headers are included in every response:
      #   X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset,
      #   X-RateLimit-Policy
      #
      module RateLimitable

        extend ActiveSupport::Concern

        RATE_LIMITS = {
          default: { window: 60, max: 120, burst: 150 },
          send:    { window: 60, max: 30,  burst: 50 },
          auth:    { window: 60, max: 20,  burst: 30 },
          admin:   { window: 60, max: 60,  burst: 80 },
        }.freeze

        included do
          before_action :check_rate_limit!
        end

        private

        def check_rate_limit!
          return unless should_rate_limit?

          identifier = rate_limit_identifier
          category = rate_limit_category
          limits = RATE_LIMITS[category] || RATE_LIMITS[:default]

          current_count = increment_counter(identifier, limits[:window])
          remaining = limits[:max] - current_count
          reset_time = (Time.now.to_f / limits[:window]).ceil * limits[:window]

          set_rate_limit_headers(limits[:max], [remaining, 0].max, reset_time, category)

          if current_count > limits[:burst]
            render_rate_limited("Rate limit exceeded — burst capacity reached")
          elsif current_count > limits[:max]
            render_rate_limited("Rate limit exceeded — try again in #{reset_time - Time.now.to_i}s")
          end
        end

        def increment_counter(identifier, window)
          key = "api_rate:#{identifier}:#{Time.now.to_i / window}"
          Rails.cache.increment(key, 1, expires_in: window * 2)
        rescue StandardError
          # If cache is unavailable, allow the request through
          0
        end

        def rate_limit_identifier
          # Prefer token-based identification, fall back to IP
          if @current_api_token
            "token:#{@current_api_token.id}"
          elsif @current_credential
            "credential:#{@current_credential.id}"
          else
            "ip:#{request.remote_ip}"
          end
        end

        def rate_limit_category
          case request.path
          when %r{/api/v2/send/}
            :send
          when %r{/api/v2/auth/}
            :auth
          when %r{/api/v2/users|/api/v2/ip_pools}
            :admin
          else
            :default
          end
        end

        def should_rate_limit?
          request.path.start_with?("/api/v2/")
        end

        def set_rate_limit_headers(limit, remaining, reset_time, policy)
          response.headers["X-RateLimit-Limit"] = limit.to_s
          response.headers["X-RateLimit-Remaining"] = remaining.to_s
          response.headers["X-RateLimit-Reset"] = reset_time.to_s
          response.headers["X-RateLimit-Policy"] = "#{limit};w=#{RATE_LIMITS[policy][:window]}"
        end

      end
    end
  end
end
