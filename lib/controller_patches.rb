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

    def principles; end
    def house_rules; end
    def how; end
    def complaints; end
    def volunteers; end
    def beginners; end

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



  # Adding an instance variable to the frontpage controller for Profile - personal data
  UserController.class_eval do

    def signchangeaddress
      if not authenticated?(
            :web => _("To change your address used on {{site_name}}",:site_name=>site_name),
            :email => _("Then you can change your address used on {{site_name}}",:site_name=>site_name),
            :email_subject => _("Change your address used on {{site_name}}",:site_name=>site_name)
           )
        # "authenticated?" has done the redirect to signin page for us
        return
      end

      if !params[:submitted_signchangeaddress_do]
        render :action => 'signchangeaddress'
        return
      else
        logger.debug @user.address = params[:signchangeaddress][:new_address]
        if not @user.valid?
          @signchangeaddress = @user
          render :action => 'signchangeaddress'
        else
          @user.save!
          # Now clear the circumstance
          flash[:notice] = _("You have now changed your address used on {{site_name}}",:site_name=>site_name)
          redirect_to user_url(@user)
        end
      end
    end

    def signchangepin
      if not authenticated?(
            :web => _("To change your PIN used on {{site_name}}",:site_name=>site_name),
            :email => _("Then you can change your PIN used on {{site_name}}",:site_name=>site_name),
            :email_subject => _("Change your PIN used on {{site_name}}",:site_name=>site_name)
           )
        # "authenticated?" has done the redirect to signin page for us
        return
      end

      if !params[:submitted_signchangepin_do]
        render :action => 'signchangepin'
        return
      else
        @user.national_id_number = params[:signchangepin][:national_id_number]
        if not @user.valid?
          @signchangepin = @user
          render :action => 'signchangepin'
        else
          @user.save!
          # Now clear the circumstance
          flash[:notice] = _("You have now changed your PIN used on {{site_name}}",:site_name=>site_name)
          redirect_to user_url(@user)
        end
      end
    end

    # Add our extra params to the sanitized list allowed at signup
    def user_params(key = :user)
      params.require(key).permit(:name, :email, :password, :password_confirmation, :national_id_number, :address)
    end

  end



  AdminRequestController.class_eval do

    def generate_upload_url

      if params[:incoming_message_id]
        incoming_message = IncomingMessage.find(params[:incoming_message_id])
        email = incoming_message.from_email
        name = incoming_message.safe_mail_from || @info_request.public_body.name
      else
        email = @info_request.public_body.request_email
        name = @info_request.public_body.name
      end

      user = User.find_user_by_email(email)
      if not user
        user = User.new(:name => name,
                        :email => email,
                        :password => PostRedirect.generate_random_token,
                        :address => 'Generated in generate_upload_url',
                        :national_id_number => '12345678901')
        user.save!
      end

      if !@info_request.public_body.is_foi_officer?(user)
        flash[:notice] = user.email + " is not an email at the domain @" + @info_request.public_body.foi_officer_domain_required + ", so won't be able to upload."
        redirect_to admin_request_url(@info_request)
        return
      end

      post_redirect = PostRedirect.new(
        :uri => upload_response_url(:url_title => @info_request.url_title),
        :user_id => user.id)
      post_redirect.save!
      url = confirm_url(:email_token => post_redirect.email_token)

      flash[:notice] = ("Send \"#{CGI.escapeHTML(name)}\" &lt;<a href=\"mailto:#{email}\">#{email}</a>&gt; this URL: <a href=\"#{url}\">#{url}</a> - it will log them in and let them upload a response to this request.").html_safe
      redirect_to admin_request_url(@info_request)
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
