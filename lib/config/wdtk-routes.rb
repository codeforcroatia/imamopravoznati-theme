# Here you can override or add to the pages in the core website

Rails.application.routes.draw do
  get '/england' => redirect('/body?tag=england', status: 302)
  get '/london' => redirect('/body?tag=london', status: 302)
  get '/scotland' => redirect('/body?tag=scotland', status: 302)
  get '/cymru' => redirect('/cy/body?tag=wales', status: 302)
  get '/wales' => redirect('/body?tag=wales', status: 302)
  get '/ni' => redirect('/body?tag=ni', status: 302)
  get '/northern-ireland' => redirect('/body?tag=ni', status: 302)

  # Add a route for the survey
  scope '/profile/survey' do
    root :to => 'user#survey', :as => :survey
    get '/reset' => 'user#survey_reset', :as => :survey_reset
  end

  get "/help/ico-guidance-for-authorities" => redirect("https://publikacije.imamopravoznati.org"),
  :as => :ico_guidance

  get "/help/zppi" => redirect("https://codeforcroatia.org/zppi"),
  :as => :zppi_text
  get '/help/principles' => 'help#principles',
      as: :help_principles

  get '/help/house_rules' => 'help#house_rules',
      as: :help_house_rules

  get '/help/how' => 'help#how',
      as: :help_how

  get '/help/complaints' => 'help#complaints',
      as: :help_complaints

  get '/help/volunteers' => 'help#volunteers',
      as: :help_volunteers

  get '/help/beginners' => 'help#beginners',
      as: :help_beginners

  get '/help/ico_officers' => 'help#ico_officers',
      as: :help_ico_officers

  get '/help/foi_motion'  => 'help#foi_motion',
    :via => 'get',
    :as => 'help_foi_motion'
  get '/help/glossary' => 'help#glossary',
      as: :help_glossary
end
