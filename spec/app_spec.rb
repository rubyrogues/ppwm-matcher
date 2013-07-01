require 'spec_helper'

describe PpwmMatcher::App do
  include Rack::Test::Methods
  include Sinatra::Auth::Github::Test::Helper

  let(:github_user) { make_user(:login => 'test_user') }
  let(:unauthorized_text) {"We weren't able to authenticate you."}

  def app
    described_class.new
  end

  describe "GET /" do
    it "redirects to github.com for authentication" do
      get '/'

      expect(last_response.headers['Location']).to include('github.com')
    end

    it "shows the code submision form" do
      login_as github_user

      get "/"

      expect(last_response.body).to include("Enter your code")
    end
  end

  describe "GET /profile/:github_login" do
    context 'the user is authorized' do
      it 'if the user exists, says Hello github_login' do
        login_as github_user

        user = PpwmMatcher::User.update_or_create('foo@example.com', github_user)
        get "/profile/#{user.github_login}"

        [:github_login, :name, :email, :gravatar_id].each do |profile_attribute|
          expect(last_response.body).to include(user.public_send(profile_attribute))
        end

      end
      it 'if user does not exists,says No such user' do
        login_as github_user

        get "/profile/#{github_user.login}"

        expect(last_response.body).to include('No such user')
      end
    end
  end

  describe "GET /unauthenticated" do
    it "should not redirect for authentication" do
      get '/unauthenticated'

      expect(last_response).not_to be_redirect
    end

    it "displays authentication error" do
      get '/unauthenticated'

      expect(last_response.body).to include(unauthorized_text)
    end
  end

  describe "POST /codes/import" do
    before do
      raise "I just saved your butt" if ENV['RACK_ENV'] != 'test'
      PpwmMatcher::Code.delete_all
    end

    let(:codes) { (1..10).map{ FactoryGirl.generate(:random_code) } }

    it "accepts a list of codes and creates them" do
      authorize 'admin', 'ZOMGSECRET'

      expect {
        post '/code/import', :codes => codes
      }.to change{ PpwmMatcher::Code.count }.by codes.length

      expect(PpwmMatcher::Code.where(:value => codes).length).to eql(codes.length)
    end

    it "requires basic auth" do
      post '/code/import', :codes => codes

      expect(last_response).not_to be_ok
    end

    it "can accept codes as raw input" do
      authorize 'admin', 'ZOMGSECRET'

      expect {
        post '/code/import', codes.join("\n"), "CONTENT_TYPE" => "text/plain"
      }.to change{ PpwmMatcher::Code.count }.by codes.length

      expect(PpwmMatcher::Code.where(:value => codes).length).to eql(codes.length)
    end
  end

  describe "POST /code" do
    it "redirects to github.com for authentication" do
      post '/code', :code => 'FOOBAR'

      expect(last_response.headers['Location']).to include('github.com')
    end

    it "redirects when an invalid code is provided" do
      login_as github_user

      post '/code', :code => 'FOOBAR'

      expect(last_response.body).to include("Unknown code, try again")
      expect(last_response.body).to include("Enter your code")
    end

    it "when a valid code is provided it shows the code" do
      login_as github_user
      code = FactoryGirl.create(:code)

      post '/code', :code => code.value, :email => github_user.email

      expect(last_response.body).to include(code.value)
    end

    it "associates the current user to the code provided"  do
      login_as github_user
      code = FactoryGirl.create(:code)

      post '/code', :code => code.value, :email => github_user.email

      expect(code.users(true).where(:email => github_user.email).size).to eql(1)
    end

    it "adds UserMailer as an observer to the given code" do
      code = FactoryGirl.create(:code)
      login_as github_user

      PpwmMatcher::UserMailer.should_receive(:new).and_call_original

      post '/code', :code => code.value, :email => github_user.email
    end
  end

  describe "GET /codes" do
    let(:codes) { FactoryGirl.create_list(:code, 10) }

    it "requires authorization" do
      get '/codes'

      expect(last_response.body).to include(unauthorized_text)
    end

    it "contains a listing of all codes" do
      codes

      authorize 'admin', 'ZOMGSECRET'
      get '/codes'

      codes.each do |code|
        expect(last_response.body).to include(code.value)
      end
    end
  end
end
