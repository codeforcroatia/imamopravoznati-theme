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

    # Adds signature for sending personal data to the Authority with FOI Request
    #RequestController.class_eval do
        include Signature

        def outgoing_message_params
          params.require(:outgoing_message).permit(:body, :what_doing, :idnumber, :phone, :address, :signature)
        end

      def new
        # All new requests are of normal_sort
        if !params[:outgoing_message].nil?
          params[:outgoing_message][:what_doing] = 'normal_sort'
        end

        # If we've just got here (so no writing to lose), and we're already
        # logged in, force the user to describe any undescribed requests. Allow
        # margin of 1 undescribed so it isn't too annoying - the function
        # get_undescribed_requests also allows one day since the response
        # arrived.
        if !@user.nil? && params[:submitted_new_request].nil?
          @undescribed_requests = @user.get_undescribed_requests
          if @undescribed_requests.size > 1
            render :action => 'new_please_describe'
            return
          end
        end

        # Banned from making new requests?
        user_exceeded_limit = false
        if authenticated? && !authenticated_user.can_file_requests?
          # If the reason the user cannot make new requests is that they are
          # rate-limited, it’s possible they composed a request before they
          # logged in and we want to include the text of the request so they
          # can squirrel it away for tomorrow, so we detect this later after
          # we have constructed the InfoRequest.
          user_exceeded_limit = authenticated_user.exceeded_limit?(:info_requests)
          if !user_exceeded_limit
            @details = authenticated_user.can_fail_html
            render :template => 'user/banned'
            return
          end
          # User did exceed limit
          @next_request_permitted_at = authenticated_user.next_request_permitted_at
        end

        # First time we get to the page, just display it
        if params[:submitted_new_request].nil? || params[:reedit]
          if user_exceeded_limit
            render :template => 'user/rate_limited'
            return
          end
          return render_new_compose
        end

        # CREATE ACTION

        # Check we have :public_body_id - spammers seem to be using :public_body
        # erroneously instead
        if params[:info_request][:public_body_id].blank?
          redirect_to frontpage_path and return
        end

        # See if the exact same request has already been submitted
        # TODO: this check should theoretically be a validation rule in the
        # model, except we really want to pass @existing_request to the view so
        # it can link to it.
        @existing_request = InfoRequest.find_existing(params[:info_request][:title], params[:info_request][:public_body_id], params[:outgoing_message][:body])

        # Create both FOI request and the first request message
        @info_request = InfoRequest.build_from_attributes(info_request_params,
                                                          outgoing_message_params)
        @outgoing_message = @info_request.outgoing_messages.first

        # Maybe we lost the address while they're writing it
        unless @info_request.public_body.is_requestable?
          render :action => "new_#{ @info_request.public_body.not_requestable_reason }"
          return
        end

        # See if values were valid or not
        if @existing_request || !@info_request.valid?
          # We don't want the error "Outgoing messages is invalid", as in this
          # case the list of errors will also contain a more specific error
          # describing the reason it is invalid.
          @info_request.errors.delete(:outgoing_messages)

          render :action => 'new'
          return
        end

        # Show preview page, if it is a preview
        if params[:preview].to_i == 1
          return render_new_preview
        end

        if user_exceeded_limit
          render :template => 'user/rate_limited'
          return
        end

        unless authenticated?
          ask_to_login(
            web: _('To send and publish your FOI request').to_str,
            email: _('Then your FOI request to {{public_body_name}} will be sent ' \
                     'and published.',
                     public_body_name: @info_request.public_body.name),
            email_subject: _('Confirm your FOI request to {{public_body_name}}',
                             public_body_name: @info_request.public_body.name)
          )
          return
        end

        @info_request.user = request_user

        if spam_subject?(@outgoing_message.subject, @user)
          handle_spam_subject(@info_request.user) && return
        end

        if blocked_ip?(country_from_ip, @user)
          handle_blocked_ip(@info_request) && return
        end

        if AlaveteliConfiguration.new_request_recaptcha && !@user.confirmed_not_spam?
          if @render_recaptcha && !verify_recaptcha
            flash.now[:error] = _('There was an error with the reCAPTCHA. ' \
                                  'Please try again.')

            if send_exception_notifications?
              e = Exception.new("Possible blocked non-spam (recaptcha) from #{@info_request.user_id}: #{@info_request.title}")
              ExceptionNotifier.notify_exception(e, :env => request.env)
            end

            render :action => 'new'
            return
          end
        end

        # This automatically saves dependent objects, such as @outgoing_message, in the same transaction
        @info_request.save!

        signum = false

        signum = gen_sig(@info_request.id, InfoRequest.hash_from_id(@info_request.id))

        if @outgoing_message.sendable?
          begin
            mail_message = OutgoingMailer.initial_request(
              @outgoing_message.info_request,
              @outgoing_message,
              signum
            ).deliver_now
          rescue *OutgoingMessage.expected_send_errors => e
            # Catch a wide variety of potential ActionMailer failures and
            # record the exception reason so administrators don't have to
            # dig into logs.
            @outgoing_message.record_email_failure(
              e.message
            )

            flash[:error] = _("An error occurred while sending your request to " \
                              "{{authority_name}} but has been saved and flagged " \
                              "for administrator attention.",
                              authority_name: @info_request.public_body.name)
          else
            @outgoing_message.record_email_delivery(
              mail_message.to_addrs.join(', '),
              mail_message.message_id
            )

            flash[:request_sent] = true
          ensure
            # Ensure the InfoRequest is fully updated before templating to
            # isolate templating issues recording delivery status.
            @info_request.save!
          end
        end

        redirect_to show_request_path(:url_title => @info_request.url_title)
      end

    end

    FollowupsController.class_eval do
        include Signature
      def send_followup
        @outgoing_message.sendable?

        # OutgoingMailer.followup() depends on DB id of the
        # outgoing message, save just before sending.
        @outgoing_message.save!

        signum = false

        #if @user && @user.is_admin? && @user.name=="Signature Testing User"
        signum = gen_sig(@outgoing_message.info_request.id, InfoRequest.hash_from_id(@outgoing_message.info_request.id))
        #end

        begin
          mail_message = OutgoingMailer.followup(
          @outgoing_message.info_request,
          @outgoing_message,
          @outgoing_message.incoming_message_followup,
          signum
          ).deliver_now
        rescue *OutgoingMessage.expected_send_errors => e
          authority_name = @outgoing_message.info_request.public_body.name
          @outgoing_message.record_email_failure(e.message)
          if @outgoing_message.what_doing == 'internal_review'
          flash[:error] = _("Your internal review request has been saved but " \
                    "not yet sent to {{authority_name}} due to an error.",
                    authority_name: authority_name)
          else
          flash[:error] = _("Your follow up message has been saved but not yet " \
                    "sent to {{authority_name}} due to an error.",
                    authority_name: authority_name)
          end
        else
          @outgoing_message.record_email_delivery(
          mail_message.to_addrs.join(', '),
          mail_message.message_id
          )

          if @outgoing_message.what_doing == 'internal_review'
          flash[:notice] = _("Your internal review request has been sent on " \
                     "its way.")
          else
          flash[:notice] = _("Your follow up message has been sent on its way.")
          end

          @outgoing_message.info_request.reopen_to_new_responses
        ensure
          # Ensure DB is updated to isolate potential templating issues
          # from impacting delivery status information.
          @outgoing_message.save!
        end
      end
    end
    # End of Signature
  end

end
