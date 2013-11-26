require 'addressable/uri'
require 'bundler/setup'
require 'fileutils'
require 'json'
require 'logger'
require 'sinatra'
require 'yaml'

class TurnAndPushApp < Sinatra::Base
  # Path to the git sources definition file
  SOURCE_FILE = File.join settings.root, 'config/sources.yml'

  # Temporaru dir for website building
  TMP_DIR = File.join settings.root, 'tmp'

  # Application log file
  LOG_FILE = File.join settings.root, "log/#{settings.environment}.log"

  # Default tail length
  TAIL_LENGTH = 10

  configure do
    enable :logging
  end

  configure :development, :test do
    set :logging, Logger::DEBUG
  end

  before do
    content_type 'text/plain', :charset => 'utf-8'
    @sources = []
    YAML.load_file(SOURCE_FILE).each do |s|
      path = Addressable::URI.parse(s['url']).path
      owner, repo = path.gsub(/(^\/+)|(\.git$)/, '').split('/', 2)
      @sources << {
        :url => s['url'],
        :owner => owner,
        :repo => repo,
        :build => s['build'],
        :deploy => s['deploy'],
      }
    end
  end

  post '/handle' do
    data = JSON.parse params[:payload]
    owner = data['repository']['owner']['name']
    repo = data['repository']['name']
    logger.info "Handling webhook: #{owner}/#{repo}"
    build(owner, repo)
  end

  get '/build/:owner/:repo' do
    owner = params[:owner]
    repo = params[:repo]
    error 401, 'Bad owner' unless owner
    error 401, 'Bad repository' unless repo
    logger.info "Build request: #{owner}/#{repo}"
    build(owner, repo)
  end

  get '/log' do
    tail
  end

  get '/log/:n' do
    error 401, 'Bad number' unless params[:n].to_s =~ /^\d{,4}$/
    tail(params[:n])
  end

  not_found do
    error 405, 'Go away!'
  end

  def build(owner, repo)
    start_time = start = Time.now
    source = @sources.find {|s| s[:owner] == owner and s[:repo] == repo}
    error 401, 'Unallowed source' unless source

    tmp_dir = File.join TMP_DIR, "#{owner}--#{repo}"

    if File.directory? tmp_dir
      logger.info 'Updating local repository'
      `cd #{tmp_dir} && git fetch --all && git reset --hard origin/master`
      if $?.to_i != 0
        logger.error 'Error merging remote changes'
        logger.info 'Purging local copy'
        FileUtils.rm_rf tmp_dir
      end
    end

    unless File.directory? tmp_dir
      logger.info "Cloning #{source[:url]} to #{tmp_dir}"
      `git clone #{source[:url]} #{tmp_dir}`
      error 500, 'Error getting site source' unless $?.to_i == 0
    end

    logger.info 'Building website'
    logger.debug cmd = [
      "cd #{tmp_dir}",
      "export BUNDLE_GEMFILE=#{tmp_dir}/Gemfile",
      "#{source[:build]}"
    ].join(' && ')
    error 500, 'Error building website' unless system cmd

    logger.info 'Deploying website'
    cmd = "cd #{tmp_dir} && #{source[:deploy]}"
    logger.debug cmd
    error 500, 'Error deploying website' unless system cmd

    seconds = (Time.now - start_time).round(2)
    logger.info "Finished in #{seconds} seconds."

    halt 200, 'Ok'
  end

  def tail(num=TAIL_LENGTH)
    logger.info "Reading #{num} lines from log tail"
    `tail -n #{num} #{LOG_FILE}`
  end

  def bundle(command)
    bundle_command = "bundle #{command}"
    error 500, "Error doing #{bundle_command}" unless system bundle_command
  end

  def error(code, message)
    logger.fatal(message)
    halt code, message
  end
end
