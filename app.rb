require 'bundler/setup'
require 'sinatra'
require 'json'
require 'fileutils'

class TurnAndPushApp < Sinatra::Base
  # Sinatra app root dir
  APP_ROOT = File.expand_path '..', __FILE__

  # Temporaru dir for website building
  TMP_DIR = File.join APP_ROOT, 'tmp'

  # Application log file
  LOG_FILE = File.join APP_ROOT, 'log/app.log'

  # Common git options for website source retrieving
  GIT_OPTS = '--depth 1 --single-branch --branch master'

  configure do
    mime_type :plain, 'text/plain'
    set :public_folder, 'public'
  end

  configure :development do
    set :logging, Logger::DEBUG
  end

  configure :production do
    set :logging, Logger::INFO
  end

  before do
    # Setting up the logging
    logger = Logger.new(LOG_FILE, 'weekly')
    logger.formatter = proc do |severity, datetime, progname, msg|
       "#{datetime.strftime('%F %T')} #{severity}: #{msg}\n"
    end
    env['rack.logger'] = logger

    # Loading configuration
    @sites = YAML.load_file File.join(APP_ROOT, 'config/sites.yml')
  end

  post '/handle' do
    logger.info "Handling webhook"
    data = JSON.parse params[:result]
    logger.debug "#{data.inspect}"

    unless data.has_key?(:repository) and data[:repository].has_key?(:name)
      error 401, 'Bad input'
    end

    build(data[:repository][:name])
  end

  get '/build/:id' do
    error 401, 'Undefined site id' unless @sites.has_key? params[:id]
    build params[:id]
  end

  get 'log/?:n?' do
    error 401, 'Bad number' unless params[:n].to_s =~ /^\d{,3}$/
    logger.info 'Reading log tail'
    num = params[:n] ? params[:n] : 100
    cmd = "tail -n #{num} #{LOG_FILE}"
    logger.debug cmd
    `#{cmd}`
  end

  get '/' do
    redirect 'index.html'
  end

  not_found do
    error 405, 'Go away!'
  end

  def build(id)
    logger.info "Building #{id}"
    git_url = @sites[id][:from]
    tmp_dir = File.join TMP_DIR, \
      "#{DateTime.now.strftime('%Y%m%d%H%M%S')}-#{id}"

    FileUtils.mkdir_p tmp_dir
    Dir.chdir tmp_dir
    cmd = "git clone #{GIT_OPTS} #{git_url} #{tmp_dir}"
    logger.debug "Cloning latest revision to temp location: #{cmd}"
    error 500, 'Error retrieving website sources' unless system cmd

    logger.debug 'Building and deploying website'
    bundle 'install'
    bundle 'exec rake generate deploy'

    logger.debug 'Cleaning up'
    FileUtils.rm_rf tmp_dir
  end

  def bundle(command)
    bundle_command = "bundle #{command}"
    error 500, "Error doing #{bundle_command}" unless system bundle_command
  end

  def error(code, message)
    logger.error(message)
    halt code, message
  end
end
