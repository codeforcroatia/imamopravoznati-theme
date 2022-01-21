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

  # Custom fields requestor details
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
              @user.address = params[:signchangeaddress][:new_address]
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

      def signchangenationalid
          if not authenticated?(
                  :web => _("To change your national ID number used on {{site_name}}",:site_name=>site_name),
                  :email => _("Then you can change your national ID number used on {{site_name}}",:site_name=>site_name),
                  :email_subject => _("Change your national ID number used on {{site_name}}",:site_name=>site_name)
                 )
              # "authenticated?" has done the redirect to signin page for us
              return
          end

          if !params[:submitted_signchangenationalid_do]
              render :action => 'signchangenationalid'
              return
          else
              @user.national_id_number = params[:signchangenationalid][:new_national_id]
              if not @user.valid?
                  @signchangenationalid = @user
                  render :action => 'signchangenationalid'
              else
                  @user.save!

                  # Now clear the circumstance
                  flash[:notice] = _("You have now changed your national ID number used on {{site_name}}",:site_name=>site_name)
                  redirect_to user_url(@user)
              end
          end
      end

      def signchangecompanyname
          if not authenticated?(
                  :web => _("To change your company name used on {{site_name}}",:site_name=>site_name),
                  :email => _("Then you can change your company name used on {{site_name}}",:site_name=>site_name),
                  :email_subject => _("Change your company name used on {{site_name}}",:site_name=>site_name)
                 )
              # "authenticated?" has done the redirect to signin page for us
              return
          end

          if !params[:submitted_signchangecompanyname_do]
              render :action => 'signchangecompanyname'
              return
          else
              @user.company_name = params[:signchangecompanyname][:new_company_name]
              if not @user.valid?
                  @signchangecompanyname = @user
                  render :action => 'signchangecompanyname'
              else
                  @user.save!
                  # Now clear the circumstance
                  flash[:notice] = _("You have now changed your company name used on {{site_name}}",:site_name=>site_name)
                  redirect_to user_url(@user)
              end
          end
      end

      def signchangecompanynumber
          if not authenticated?(
                  :web => _("To change your company number used on {{site_name}}",:site_name=>site_name),
                  :email => _("Then you can change your company number used on {{site_name}}",:site_name=>site_name),
                  :email_subject => _("Change your company number used on {{site_name}}",:site_name=>site_name)
                 )
              # "authenticated?" has done the redirect to signin page for us
              return
          end

          if !params[:submitted_signchangecompanynumber_do]
              render :action => 'signchangecompanynumber'
              return
          else
              @user.company_number = params[:signchangecompanynumber][:new_company_number]
              if not @user.valid?
                  @signchangecompanynumber = @user
                  render :action => 'signchangecompanynumber'
              else
                  @user.save!
                  # Now clear the circumstance
                  flash[:notice] = _("You have now changed your company number used on {{site_name}}",:site_name=>site_name)
                  redirect_to user_url(@user)
              end
          end
      end

      def user_params(key = :user)
          # Override user_params whitelist to allow our additional fields
          params[key].slice(:name, :email, :password, :password_confirmation,
                            :user_type, :address, :national_id_number,
                            :company_name, :company_number)
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
