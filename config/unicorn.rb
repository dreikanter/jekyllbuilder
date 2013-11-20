app_root = File.expand_path '../..', __FILE__

worker_processes 2
working_directory app_root
timeout 30
user 'pi'
listen "#{app_root}/tmp/sockets/unicorn.sock", :backlog => 64
pid "#{app_root}/tmp/pids/unicorn.pid"
stderr_path "#{app_root}/log/unicorn.log"
stdout_path "#{app_root}/log/unicorn.log"
