RAILS_REQUIREMENT = "~>6.0.0".freeze

GEMS = {
  "haml-rails": "~> 2.0",
  "friendly_id": "~> 5.4",
  "devise": "~> 4.8",
  "omniauth-marvin": "~> 1.2"
}.freeze

GEMS_DEV = { 
  "dotenv-rails": "~> 2.7",
  "rspec-rails": "~> 5.0"
}.freeze

# -- 

def apply_template!
  assert_minimum_rails_version

  run "spring stop"
  del_comment 'Gemfile'
  
  add_gems
  add_bootstrap_n_fa
  add_haml
  add_friendly_id
  add_home
  add_users
  add_rspec

  do_git

  after_bundle do 
    say "---"
    say 
    say "App successfully created!", :blue
    say 
    say "Gems installed:", :green 
    GEMS.each { |k, _| say "  - #{k}"}
    GEMS_DEV.each { |k, _| say "  - #{k}" }
    say 
    say "To get started with your new app:", :green
    say "  - cd #{app_name}"
    say "  - Update config/database.yml with your database credentials"
    say "  - rails db:create db:migrate"
    say "  - set your FT_ID and FT_SECRET into your .env with credentials generated here: https://profile.intra.42.fr/oauth/applications"
  end
end



def assert_minimum_rails_version
  requirement = Gem::Requirement.new(RAILS_REQUIREMENT)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)
  return if requirement.satisfied_by?(rails_version)

  prompt = "This template requires Rails #{RAILS_REQUIREMENT}. "\
            "You are using #{rails_version}. Continue anyway? [Y/n]"
  exit 1 if no?(prompt)
end

def yarn(lib) 
  run("yarn add #{lib}") 
end

def del_comment(file)
  gsub_file(file, /^\s*#.*$\n/, '')
end

def add_haml
  rails_command "haml:erb2haml HAML_RAILS_DELETE_ERB=true"
end

def add_home
  generate "controller Home index"
  gsub_file 'config/routes.rb', /^\s*get\s*'home\/index'$/, "  root to: 'home#index'"
end

def add_friendly_id
  generate "friendly_id"
end

def add_rspec
  generate "rspec:install"
  run "rm -rf test" if yes?("Do you want to remove the /test directory? [Y/n]")
end

def add_gems
  GEMS.each do |k, v| 
    gem k.to_s, v
  end

  gem_group :development, :test do
    GEMS_DEV.each do |k, v|
      gem k.to_s, v
    end
  end
end


def add_bootstrap_n_fa
  yarn 'bootstrap@next @popperjs/core @fortawesome/fontawesome-free'

  inject_into_file 'app/javascript/packs/application.js', after: "// that code so it'll be compiled.\n" do <<-JAVASCRIPT

import 'bootstrap/dist/js/bootstrap';
import 'bootstrap/dist/css/bootstrap';
import '@fortawesome/fontawesome-free/css/all';
JAVASCRIPT
  end
end

def add_users
  generate "devise:install"

  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'

  inject_into_file 'app/views/layouts/application.html.haml', after: "  %body\n" do <<-HAML
    %p.notice= notice
    %p.alert= alert
    = link_to "Sign in with 42", user_marvin_omniauth_authorize_path unless current_user
    = link_to "Sign out", destroy_user_session_path, method: :delete if current_user
HAML
    end

  generate :devise, "User", "first_name", "last_name", "login"

  generate "devise:controllers users -c=omniauth_callbacks"

  del_comment 'app/controllers/users/omniauth_callbacks_controller.rb'
  
  insert_into_file 'app/controllers/users/omniauth_callbacks_controller.rb', before: /^end$/ do <<-RUBY

  def marvin
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "42") if is_navigational_format?
    else
      session["devise.marvin_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end
  
  def after_omniauth_failure_path_for scope
    # instead of root_path you can add sign_in_path if you end up to have your own sign_in page.
    root_path
  end

RUBY
  end

  insert_into_file "config/initializers/devise.rb", "  config.omniauth :marvin, ENV[\"FT_ID\"], ENV[\"FT_SECRET\"]\n\n", 
    before: "  # ==> Warden configuration"

  # prepare user.rb model
  gsub_file 'app/models/user.rb', /^\s*devise.*$\n/, "  devise :omniauthable, omniauth_providers: [:marvin]\n"
  gsub_file 'app/models/user.rb', /^\s*:recoverable.*$\n/, ''

  del_comment 'app/models/user.rb'
  
  insert_into_file 'app/models/user.rb', after: "  devise :omniauthable, omniauth_providers: [:marvin]\n" do <<-RUBY

  def self.from_omniauth(auth)
    where(login: auth.info.login).first_or_create do |user|
      user.email = auth.info.email
      user.login = auth.info.login
      user.first_name = auth.info.first_name
      user.last_name = auth.info.last_name
    end
  end
RUBY
  end

  in_root do
    migration = Dir.glob("db/migrate/*").max_by{ |f| File.mtime(f) }
    gsub_file migration, /^\s*## Recov.*\n.*\n.*$/, ""
    gsub_file migration, /^\s*## Rememberable.*\n.*$/, ""
    gsub_file migration, /^\s*add_index\s.*:users,\s.*:reset_password_token.*$/, ""
  end

  del_comment('config/routes.rb')

  gsub_file 'config/routes.rb', /^\s*devise.*$/, "  devise_for :users, controllers: { omniauth_callbacks: \"users/omniauth_callbacks\" }"
    
  insert_into_file 'config/routes.rb', after: /^\s*devise_for :users.*\n/ do <<-RUBY
  devise_scope :user do
    delete 'sign_out', to: 'devise/sessions#destroy', as: :destroy_user_session
  end


RUBY
  end

end

def do_git
  unless ENV["SKIP_GIT"]
    git :init
    git add: "."
    # git commit will fail if user.email is not configured
    begin
      git commit: %( -m 'Initial commit' )
    rescue StandardError => e
      puts e.message
    end
  end
end


apply_template!