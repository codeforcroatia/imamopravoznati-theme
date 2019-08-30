# Here you can override or add to the pages in the core website

Rails.application.routes.draw do
  get '/zagreb' => redirect('/body?tag=zagreb', status: 302)

  # Add a route for the survey
  scope '/profile/survey' do
    root :to => 'user#survey', :as => :survey
    get '/reset' => 'user#survey_reset', :as => :survey_reset
  end

  get "/help/ico-guidance-for-authorities" => redirect("http://0.codeforcroatia.org/ppi-smjernice-za-sluzbenike/"),
  :as => :ico_guidance
end
