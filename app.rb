require 'bundler/setup'
require 'sinatra'
require 'json'
require 'fileutils'
require 'logger'
require 'addressable/uri'
require 'yaml'
require 'pp'
require 'git'

class TurnAndPushApp < Sinatra::Base
  # Path to the list of allowed git sources
  ALLOWED_SOURCES = File.join settings.root, "config/allowed-sources.yml"

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
    YAML.load_file(ALLOWED_SOURCES).each do |url|
      path = Addressable::URI.parse(url).path
      owner, repo = path.gsub(/(^\/+)|(\.git$)/, '').split('/', 2)
      @sources << {:url => url, :owner => owner, :repo => repo }
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
    source = @sources.find {|s| s[:owner] == owner and s[:repo] == repo}
    unless source
      error 401, 'Unallowed source'
    end

    tmp_dir = File.join TMP_DIR, "#{owner}-#{repo}"
    begin
      Git.open(tmp_dir).pull(source[:url])
      logger.info "#{source[:url]} updated at #{tmp_dir}"
    rescue ArgumentError
      FileUtils.rm_rf tmp_dir if File.directory? tmp_dir
      Git.clone(source[:url], tmp_dir)
      logger.debug "#{source[:url]} cloned to #{tmp_dir}"
    end

    logger.debug 'Building and deploying website'
    Dir.chdir tmp_dir do
      bundle 'exec rack generate'
    end
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
    logger.error(message)
    halt code, message
  end
end
