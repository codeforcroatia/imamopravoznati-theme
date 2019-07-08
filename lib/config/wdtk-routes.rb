# Here you can override or add to the pages in the core website

Rails.application.routes.draw do
    # Add a route for the survey
    scope '/profile/survey' do
        root :to => 'user#survey', :as => :survey
        match '/reset' => 'user#survey_reset', :as => :survey_reset
    end

    match "/help/ico-guidance-for-authorities" => redirect("https://ico.org.uk/media/for-organisations/documents/how-to-disclose-information-safely-removing-personal-data-from-information-requests-and-datasets/1432979/how-to-disclose-information-safely.pdf
"),
    	:as => :ico_guidance
end
