#!/bin/bash
set -e

# Allow localhost on any port
cat >> /opt/postal/app/config/environments/test.rb << 'RUBY'

# Allow any localhost port for dev access
Rails.application.config.hosts << /localhost(\:\d+)?/
RUBY

# Precompile assets (survives container restart)
if [ ! -f /opt/postal/app/public/assets/.precompiled ]; then
  echo "==> Precompiling assets..."
  RAILS_GROUPS=assets bundle exec rake assets:precompile
  touch /opt/postal/app/public/assets/.precompiled
  echo "==> Assets ready."
fi

echo "==> Starting Postal web server..."
exec bin/postal web-server
