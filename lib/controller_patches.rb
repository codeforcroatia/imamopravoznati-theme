Rails.configuration.to_prepare do
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

    before_action :set_recaptcha_required, :only => [:contact, :foi_motion]

    def foi_motion
      @foi_motion_email = AlaveteliConfiguration::external_reviewers
      if feature_enabled?(:alaveteli_pro) && @user && @user.is_pro?
        @foi_motion_email = AlaveteliConfiguration::external_reviewers
      end

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

      # submit form
      if params[:submitted_contact_form]
        if @user
          params[:foi_motion][:email] = @user.email
          params[:foi_motion][:name] = @user.name
        end
        @foi_motion = ContactValidator.new(params[:contact])

        if (@recaptcha_required &&
            !params[:remove] &&
            !verify_recaptcha)
          flash.now[:error] = _('There was an error with the reCAPTCHA. ' \
                                'Please try again.')
        elsif @foi_motion.valid? && !params[:remove]
          ContactMailer.to_admin_message(
            params[:foi_motion][:name],
            params[:foi_motion][:email],
            params[:foi_motion][:subject],
            params[:foi_motion][:message],
            @user,
            @last_request, @last_body
          ).deliver_now
          flash[:notice] = _("Your message has been sent. Thank you for getting in touch! We'll get back to you soon.")
          redirect_to frontpage_url
          return
        end

        if params[:remove]
            @foi_motion.errors.clear
        end
      end
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
