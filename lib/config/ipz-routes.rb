# -*- encoding : utf-8 -*-
# Here you can override or add to the pages in the core website

Rails.application.routes.draw do
  # Add a route for the personal data in profile
  scope '/profile' do
    match '/change_address' => 'user#signchangeaddress',
          :as => :signchangeaddress,
          :via => [:get, :post]
    match '/change_pin' => 'user#signchangepin',
          :as => :signchangepin,
          :via => [:get, :post]
  end

  get '/london' => redirect('/body?tag=london', status: 302)

  # Add a route for the survey
  scope '/profile/survey' do
    root :to => 'user#survey', :as => :survey
    get '/reset' => 'user#survey_reset', :as => :survey_reset
  end

  get "/help/ico-guidance-for-authorities" => redirect("https://0.codeforcroatia.org/ppi-smjernice-za-sluzbenike/"),
  :as => :ico_guidance

  get '/help/principles'  => 'help#principles',
    :via => 'get',
    :as => 'help_principles'

  get '/help/house_rules'  => 'help#house_rules',
    :via => 'get',
    :as => 'help_house_rules'

  get '/help/how'  => 'help#how',
    :via => 'get',
    :as => 'help_how'

  get '/help/complaints'  => 'help#complaints',
    :via => 'get',
    :as => 'help_complaints'

  get '/help/volunteers'  => 'help#volunteers',
    :via => 'get',
    :as => 'help_volunteers'

  get '/help/beginners'  => 'help#beginners',
    :via => 'get',
    :as => 'help_beginners'
end
