# Here you can override or add to the pages in the core website

Rails.application.routes.draw do
  match '/blog' => redirect('/')
end

# WDTK Survey

Rails.application.routes.draw do
    # Add a route for the survey
    scope '/profile/survey' do
        root :to => 'user#survey', :as => :survey
        match '/reset' => 'user#survey_reset', :as => :survey_reset
    end

    match "/help/ppi-guidance-for-authorities" => redirect("http://www.pristupinfo.hr/"),
    	:as => :ico_guidance
end
