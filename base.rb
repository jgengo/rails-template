GEMS = {
  "haml-rails": "~> 2.0",
  "friendly_id": "~> 5.4"
}

def yarn(lib) 
  run("yarn add #{lib}") 
end

def stop_spring
  run "spring stop"
end

def del_comment_gemfile
  gsub_file('Gemfile', /^\s*#.*$\n/, '')
end

def add_haml
  rails_command "haml:erb2haml HAML_RAILS_DELETE_ERB=true"
end

def add_home
  generate "controller Home index"
  route "root to: 'home#index'"
end

def add_friendly_id
  generate "friendly_id"
end

def add_gems
  GEMS.each do |k, v| 
    gem k.to_s, v
  end
end

def add_bootstrap_n_fa
  yarn 'bootstrap@next'
  yarn '@popperjs/core'
  yarn '@fortawesome/fontawesome-free'

  inject_into_file 'app/javascript/packs/application.js', after: "// that code so it'll be compiled.\n" do <<-'EOF'

import 'bootstrap/dist/js/bootstrap';
import 'bootstrap/dist/css/bootstrap';
import '@fortawesome/fontawesome-free/css/all';
EOF
  end
end

after_bundle do
  stop_spring
  del_comment_gemfile
  add_gems

  add_bootstrap_n_fa
  add_haml
  add_friendly_id
  add_home

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

  say "---"
  say 
  say "App successfully created!", :blue
  say 
  say "Gems installed:", :green 
  GEMS.each { |k, _| say "  - #{k}"}
  say 
  say "To get started with your new app:", :green
  say "  - cd #{app_name}"
  say "  - Update config/database.yml with your database credentials"
  say "  - rails db:create db:migrate"
end




