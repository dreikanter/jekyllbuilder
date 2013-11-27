app_root = File.expand_path '../..', __FILE__

worker_processes 1
working_directory app_root
timeout 180
user 'pi', 'pi'
listen 8000
pid "#{app_root}/tmp/pids/unicorn.pid"

env = ENV['RACK_ENV'] || 'production'
stderr_path "#{app_root}/log/#{env}.log"
stdout_path "#{app_root}/log/#{env}.log"
