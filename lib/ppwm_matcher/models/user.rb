module PpwmMatcher
  class User < ActiveRecord::Base
    self.table_name_prefix = "ppwm_matcher_"

    attr_accessible :email, :code_id, :name, :gravatar_id

    belongs_to :code, validate: true
    validates :email, presence: true

    def has_code?
      code_id.present?
    end

    def has_pair?
      !!pair
    end

    def pair
      return false unless code_id

      User.where(:code_id => self.code_id).detect{|u| u != self }
    end

    def self.current(github_login)
      where(:github_login => github_login).limit(1).first
    end

    def self.update_or_create(email, github_user)
      user = where(:github_login => github_user.login).first_or_initialize

      user.update_attributes(:gravatar_id   => github_user.gravatar_id,
                             :name          => github_user.name,
                             :email         => email)

      user
    end
  end
end
