Gem::Specification.new do |s|
  s.name        = 'ppwm-matcher'
  s.version     = '0.0.1'
  s.authors     = ['Avdi Grimm']
  s.email       = ['']
  s.homepage    = 'https://github.com/rubyrogues/ppwm-matcher'
  s.summary     = ''
  s.description = ''

  s.files = Dir['{config,db,lib,models,public}/**/*']

  s.add_dependency 'sinatra_auth_github'
  s.add_dependency 'activerecord'
  s.add_dependency 'sinatra-activerecord'
  s.add_dependency 'pg'
  s.add_dependency 'rake'
  s.add_dependency 'pony'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'faker'
  s.add_development_dependency 'factory_girl'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'mailcatcher'

  s.add_development_dependency 'guard'
  s.add_development_dependency 'guard-bundler'
  s.add_development_dependency 'guard-rspec'
end
