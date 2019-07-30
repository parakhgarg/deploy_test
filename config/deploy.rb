# config valid only for current version of Capistrano
lock '3.11.0'
# Change these

set :repo_url,        'git@github.com:parakhgarg/deploy_test.git'
set :application,     'deploy_test'
set :user,            'deploy'
set :puma_threads,    [4, 16]
set :puma_workers,    2

# Don't change these unless you know what you're doing
set :pty,             true
set :use_sudo,        false
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.error.log"
set :output, "#{release_path}/log/cron.log"
set :puma_error_log,  "#{release_path}/log/puma.access.log"
set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa) }
set :puma_preload_app, true
set :puma_worker_timeout, 120
set :puma_init_active_record, true  # Change to false when not using ActiveRecord
set :rails_env, "production"
# set :assets_dependencies, %w(app/assets lib/assets vendor/assets Gemfile.lock config/routes.rb)
## Defaults:
# set :scm,           :git
# set :branch,        :capistrano
# set :format,        :pretty
# set :log_level,     :debug
set :keep_releases, 2

## Linked Files & Directories (Default None):
# set :linked_files, %w{config/database.yml}
# set :linked_dirs,  %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}
set :linked_dirs,  %w{log}
set :rvm_ruby_version, 'ruby-2.6.3'

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  before :start, :make_dirs
end

namespace :deploy do
  desc "Make sure local git is in sync with remote."
  task :check_revision do
    on roles(:app) do
      unless `git rev-parse HEAD` == `git rev-parse origin/#{fetch(:branch)}`
        puts "WARNING: HEAD is not the same as origin/#{fetch(:branch)}"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end

  desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'puma:restart'
    end
  end

  task :fix_absent_manifest_bug do
    on roles(:web) do
      within release_path do  execute :touch,
        release_path.join('public/assets/', 'manifest-fix.temp')
      end
    end
  end

  after :updating, 'deploy:fix_absent_manifest_bug'
  before :starting,     :check_revision
  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  after  :finishing,    :restart
end

# ps aux | grep puma    # Get puma pid
# kill -s SIGUSR2 pid   # Restart puma
# kill -s SIGTERM pid   # Stop puma