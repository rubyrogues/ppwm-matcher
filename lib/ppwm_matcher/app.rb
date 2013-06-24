require 'logger'
require 'sinatra'
require 'sinatra_auth_github'
require 'pony'
require 'ppwm_matcher/models/code'
require 'ppwm_matcher/models/user'
require 'ppwm_matcher/models/code_matcher'
require 'ppwm_matcher/models/github_auth'
require 'ppwm_matcher/observers/user_mailer'

module PpwmMatcher
  class App < Sinatra::Base
    enable :sessions
    enable :prefixed_redirects
    enable :logging

    set :github_options, PpwmMatcher::GithubAuth.options.merge(:failure_app => self)

    http_defaults = -> do
      set :admin_username, ENV.fetch('ADMIN_USERNAME') { 'admin' }
      set :admin_password, ENV.fetch('ADMIN_PASSWORD') { 'ZOMGSECRET' }
    end

    configure :test, :development do
      http_defaults.call
      Pony.options = {
        :via => :smtp,
        :via_options => {
          :address => 'localhost',
          :port => '1025'
        }
      }
    end

    configure :production do
      http_defaults.call
      Pony.options = {
        :via => :smtp,
        :via_options => {
          :address => 'smtp.sendgrid.net',
          :port => '587',
          :domain => 'heroku.com',
          :user_name => ENV['SENDGRID_USERNAME'],
          :password => ENV['SENDGRID_PASSWORD'],
          :authentication => :plain,
          :enable_starttls_auto => true
        }
      }
    end

    register Sinatra::Auth::Github

    # actions that don't require GH auth
    open_actions = %w(unauthenticated code/import codes)

    before '/*' do
      return if open_actions.include? params[:splat].first
      authenticate!
    end

    helpers do
      def repos
        github_request("user/repos")
      end

      def protected!
        return if authorized?

        headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
        halt 401, "Not authorized\n"
      end

      def authorized?
        auth =  Rack::Auth::Basic::Request.new(request.env)

        auth.credentials == [settings.admin_username, settings.admin_password]
      rescue
        false
      end
    end

    get '/' do
      setup_for_root_path
      erb :index, layout: :layout
    end

    get '/unauthenticated' do
      erb :unauthenticated, layout: :layout
    end

    post '/code/import' do
      protected!

      codes = params['codes'] || request.body.read.split("\n")

      codes.each do |code|
        Code.create!(:value => code)
      end
    end

    get '/profile/:github_login' do
      # TODO revisit how to ensure we get a safe string
      github_login = params[:github_login].to_s.gsub(/[\s-\/\\\.]/, '')
      user = User.current(github_login)
      if user
        "Hello #{github_login}"
      else
        "No such user"
      end
    end
    get '/code' do
      user = User.current(github_user.login) # TODO: refactor to helper method ?
      redirect '/' unless user && user.code

      @pair = user.pair
      @code_value = user.code.value
      erb :code, layout: :layout
    end

    post '/code' do
      matcher = CodeMatcher.new({
        github_user: github_user,
        email: params['email'],
        code: params['code']
      })

      if matcher.code
        # Send mails if both pairs have signed in
        mailer = UserMailer.new(Pony)
        matcher.code.add_observer(mailer)
      end

      if matcher.valid? && matcher.assign_code_to_user
        @pair = matcher.user.pair
        @code_value = matcher.code.value
        erb :code, layout: :layout
      else
        setup_for_root_path(matcher.error_messages)
        erb :index, layout: :layout
      end
    end

    def setup_for_root_path(messages = nil)
      @code = params['code']
      @messages = messages
      @email = params['email'] || github_user.email
      @name = github_user.name || github_user.login

      user = User.current(github_user.login)
      if user && user.has_code?
        @has_code = true
      end
    end

    get '/codes' do
      protected!

      @codes = Code.listing

      erb :codes, layout: :layout
    end
  end
end
