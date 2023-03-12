Rails.configuration.to_prepare do

  ClassificationsController.class_eval do
    # Patching classification controller
    def create
      # existing code from the ClassificationsController
      set_last_request(@info_request)

      if params[:last_info_request_event_id].to_i != @info_request.
          last_event_id_needing_description
        flash[:error] = _('The request has been updated since you originally ' \
                          'loaded this page. Please check for any new incoming ' \
                          'messages below, and try again.')
        redirect_to_info_request
        return
      end

      event = set_described_state

      # If you're not the *actual* requester. e.g. you are playing the
      # classification game, or you're doing this just because you are an
      # admin user (not because you also own the request).
      unless @info_request.is_actual_owning_user?(current_user)
        # Create a classification event for league tables
        RequestClassification.create!(
          user_id: current_user.id,
          info_request_event_id: event.id
        )

        # Don't give advice on what to do next, as it isn't their request
        if session[:request_game]
          flash[:notice] = { partial: 'request_game/thank_you.html.erb',
                             locals: {
                               info_request_title: @info_request.title,
                               url: request_path(@info_request)
                             } }
          redirect_to categorise_play_url
        else
          flash[:notice] = _('Thank you for updating this request!')
          redirect_to_info_request
        end
        return
      end

      # Display advice for requester on what to do next, as appropriate
      calculated_status = @info_request.calculate_status
      partial_path = 'request/describe_notices'
      if template_exists?(calculated_status, [partial_path], true)
        flash[:notice] =
          {
            partial: "#{partial_path}/#{calculated_status}",
            locals: {
              info_request_id: @info_request.id,
              annotations_enabled: feature_enabled?(:annotations)
            }
          }
      end

      @@custom_states_loaded = true

      case calculated_status
      when 'waiting_response', 'waiting_response_overdue', 'not_held',
        'successful', 'internal_review', 'error_message', 'requires_admin'
        redirect_to_info_request
      when *InfoRequest::State.unhappy
        redirect_to unhappy_url(@info_request)
      # Adding a controller patch for correction asked
      # Based on: https://github.com/mysociety/alaveteli/blob/hotfix/0.39.1.5/app/controllers/classifications_controller.rb#L81
    when 'waiting_clarification', 'user_withdrawn', 'correction_asked'
        redirect_to respond_to_last_url(@info_request)
      when 'gone_postal'
        redirect_to respond_to_last_url(@info_request) + '?gone_postal=1'
      else
        return theme_describe_state(@info_request) if @@custom_states_loaded

        raise "unknown calculate_status #{@info_request.calculate_status}"
      end

    end
  end

  UserController.class_eval do
    require 'survey'

    def survey
    end

    # Reset the state of the survey so it can be answered again.
    # Handy for testing; not allowed in production.
    def survey_reset
      raise "Not allowed in production" if ENV["RAILS_ENV"] == "production"
      raise "Not logged in" if !@user
      @user.survey.allow_new_survey
      return redirect_to survey_url
    end
  end

  Users::MessagesController.class_eval do

    private

    def set_recaptcha_required
      @recaptcha_required =
        AlaveteliConfiguration.user_contact_form_recaptcha &&
        request_from_foreign_country?
    end

    def request_from_foreign_country?
      country_from_ip != AlaveteliConfiguration.iso_country_code
    end

  end

  HelpController.class_eval do

    before_action :set_recaptcha_required, :only => [:contact, :foi_motion, :unhappy]

    def foi_motion
      # if they clicked remove for link to request/body, remove it
      if params[:remove]
        @last_request = nil
        cookies["last_request_id"] = nil
        cookies["last_body_id"] = nil
      end

      # look up link to request/body
      request = InfoRequest.find_by(id: cookies["last_request_id"].to_i)
      @last_request = request if can?(:read, request)

      @last_body = PublicBody.find_by(id: cookies["last_body_id"].to_i)

    end

    def principles; end
    def house_rules; end
    def how; end
    def complaints; end
    def volunteers; end
    def beginners; end
#    def foi_motion; end

    private

    def set_recaptcha_required
      @recaptcha_required =
        AlaveteliConfiguration.contact_form_recaptcha &&
        request_from_foreign_country?
    end

    def request_from_foreign_country?
      country_from_ip != AlaveteliConfiguration.iso_country_code
    end

  end


  RequestController.class_eval do
    before_action :check_spam_terms, only: [:new]

    def check_spam_terms
      return true unless params[:outgoing_message]
      return true unless params[:outgoing_message][:body]

      if spammer?(params[:outgoing_message][:body])
        # if they're signed in, ban them and redirect them to their profile
        # so that they can see they've been banned
        # otherwise, just prevent the form submission
        if @user
          msg = "Blocked user for use of spam terms, " \
                "email: #{@user.email}, " \
                "name: '#{@user.name}'"
          Rails.logger.warn(msg)

          @user.update!(ban_text: 'Account closed', closed_at: Time.zone.now)
          clear_session_credentials
          redirect_to show_user_path(@user.url_name)
        else
          msg = "Prevented unauthenticated user submitting spam term."
          Rails.logger.warn(msg)

          redirect_to root_path
          true
        end
      else
        true
      end
    end

    def spammer?(text)
      return false unless spam_terms.any?
      # https://stackoverflow.com/a/43278823/387558
      # String#match? is Ruby 2.4.0 only so need to tweak
      # Need to make a case-insensitive regexp for each term then join them all
      # together
      text =~ Regexp.union(spam_terms.map { |t| Regexp.new(/#{t}/i) })
    end

    def spam_terms
      config = Rails.root + 'tmp/spam_terms.txt'
      if File.exist?(config)
        File.read(config).split("\n")
      else
        []
      end
    end
  end

end
