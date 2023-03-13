# -*- coding: utf-8 -*-
# Add a callback - to be executed before each request in development,
# and at startup in production - to patch existing app classes.
# Doing so in init/environment.rb wouldn't work in development, since
# classes are reloaded, but initialization is not run each time.
# See http://stackoverflow.com/questions/7072758/plugin-not-reloading-in-development-mode
#
Rails.configuration.to_prepare do
    ReplyToAddressValidator.invalid_reply_addresses = %w(
      FOIResponses@homeoffice.gsi.gov.uk
      FOIResponses@homeoffice.gov.uk
      autoresponder@sevenoaks.gov.uk
      H&FInTouch@lbhf.gov.uk
      noreply@imamopravoznati.org
    )

    User.class_eval do
        # Return this user’s survey
        def survey
            return @survey if @survey
            @survey = MySociety::Survey.new(AlaveteliConfiguration::site_name, self.email)
        end
    end

    # HACK: Now patch the validator for UserInfoRequestSentAlert.alert_type
    # to permit 'survey_1' as a new alert type. This uses unstable internal
    # methods.
    #
    # TODO: This looks like its just adding another option to
    # `validates_inclusion_of :alert_type, :in => ALERT_TYPES`. This would be
    # better done by a `cattr_reader` so that themes could set the options on
    # app boot in an initializer:
    #
    #    UserInfoRequestSentAlert.alert_types = %w(custom set of alerts)
    #
    # The validation macro would then be:
    #
    #    validates_inclusion_of :alert_type, :in => alert_types
    #
    UserInfoRequestSentAlert._validate_callbacks.first.filter.options[:in] << 'survey_1'

    InfoRequest.class_eval do
        def self.theme_short_description(state)
          {
            'correction_asked' => _('Asked for correction'),
            'deadline_extended' => _('Deadline extended'),
            'payment_requested' => _('Payment requested'),
            'referred' => _('Referred'),
            'transferred' => _('Transferred')
          }[state]
        end

        # Deadline extension to the FOI request
        def extension_days
            15
        end

        def waiting_response?
            described_state == "waiting_response" ||
              described_state == "deadline_extended" ||
              described_state == "transferred" ||
              described_state == "correction_asked"
        end

        def has_extended_deadline?
            info_request_events.any?{ |event| event.described_state == 'deadline_extended' }
        end

        def reply_late_after_days
            if has_extended_deadline?
                AlaveteliConfiguration::reply_late_after_days + extension_days
            else
                AlaveteliConfiguration::reply_late_after_days
            end
        end

        def reply_very_late_after_days
            if has_extended_deadline?
                AlaveteliConfiguration::reply_very_late_after_days + extension_days
            else
                AlaveteliConfiguration::reply_very_late_after_days
            end
        end

        def date_response_required_by
            Holiday.due_date_from(date_initial_request_last_sent_at,
                                  reply_late_after_days,
                                  AlaveteliConfiguration::working_or_calendar_days)
        end

        def date_very_overdue_after
            Holiday.due_date_from(date_initial_request_last_sent_at,
                                  reply_very_late_after_days,
                                  AlaveteliConfiguration::working_or_calendar_days)
        end

        def email_subject_request(opts = {})
            html = opts.fetch(:html, true)
            subject_title = html ? self.title : self.title.html_safe
            if (!is_batch_request_template?) && (public_body && public_body.url_name == 'general_register_office')
                # without GQ in the subject, you just get an auto response
                _('{{law_used_full}} request GQ - {{title}}', :law_used_full => law_used_human(:full),
                                                              :title => subject_title)
            else
                _('{{law_used_full}} request - {{title}}', :law_used_full => law_used_human(:full),
                                                           :title => subject_title)
            end
        end

        alias_method :orig_late_calculator, :late_calculator

        def late_calculator
          @late_calculator ||=
            if public_body.has_tag?('school')
              SchoolLateCalculator.new
            else
              orig_late_calculator
            end
        end
    end

    # Patch InfoRequestEvent
    InfoRequestEvent.class_eval do

        # Action events that reset due date
        def resets_due_dates?
           is_request_sending? || is_clarification? || is_transferred? || is_correction_asked?
        end

        # Transferrred request to another authority resets due date
        def is_transferred?
          transferred = false
          # A response is a transferred only if it's the first
          # response when the request is in a state of transferred
          previous_events(:reverse => true).each do |event|
            if event.described_state == 'transferred'
              transferred = true
              break
            end
            if event.event_type == 'response'
              break
            end
          end
          transferred && event_type == 'response'
        end

        # User asked for a correction resets due date
        def is_correction_asked?
          correction_asked = false
          # A response is a correction_asked only if it's the first
          # response when the request is in a state of correction_asked
          previous_events(:reverse => true).each do |event|
            if event.described_state == 'transferred'
              correction_asked = true
              break
            end
            if event.event_type == 'response'
              break
            end
          end
          correction_asked && event_type == 'response'
        end

    end

    PublicBody.class_eval do
      # Return the domain part of an email address, canonicalised and with common
      # extra UK Government server name parts removed.
      #
      # TODO: Extract to library class
      def self.extract_domain_from_email(email)
        email =~ /@(.*)/
        if $1.nil?
          return nil
        end

        # take lower case
        ret = $1.downcase

        # remove special email domains for UK Government addresses
        %w(gsi x pnn).each do |subdomain|
          if ret =~ /.*\.*#{ subdomain }\.*.*\.gov\.uk$/
            ret.sub!(".#{ subdomain }.", '.')
          end
        end

        return ret
      end

      def is_school?
        has_tag?('school')
      end
    end

    module SurveyMethods
        def survey_alert(info_request)
            user = info_request.user

            post_redirect = PostRedirect.new(
                :uri => survey_url,
                :user_id => user.id)
            post_redirect.save!
            @url = confirm_url(:email_token => post_redirect.email_token)

            headers('Return-Path' => blackhole_email, 'Reply-To' => contact_from_name_and_email, # not much we can do if the user's email is broken
                    'Auto-Submitted' => 'auto-generated', # http://tools.ietf.org/html/rfc3834
                    'X-Auto-Response-Suppress' => 'OOF')
            @info_request = info_request
            mail(:to => user.name_and_email,
                 :from => contact_from_name_and_email,
                 :subject => "Can you help us improve ImamoPravoZnati?")
        end

        module ClassMethods
            # Send an email with a link to the survey two weeks after a request was made,
            # if the user has not already completed the survey.
            def alert_survey
                # Exclude requests made by users who have already been alerted about the survey
                info_requests = InfoRequest.where(
                        " created_at between now() - '2 weeks + 1 day'::interval and now() - '2 weeks'::interval" +
                        " and user_id is not null" +
                        " and not exists (" +
                        "     select *" +
                        "     from user_info_request_sent_alerts" +
                        "     where user_id = info_requests.user_id" +
                        "      and  alert_type = 'survey_1'" +
                        " )"
                ).includes(:user)

                # TODO: change the initial query to iterate over users rather
                # than info_requests rather than using an array to check whether
                # we're about to send multiple emails to the same user_id
                sent_to = []
                for info_request in info_requests
                    # Exclude users who have already completed the survey or
                    # have already been sent a survey email in this run
                    logger.debug "[alert_survey] Considering #{info_request.user.url_name}"
                    next if !info_request.user.can_send_survey? || sent_to.include?(info_request.user_id)

                    store_sent = UserInfoRequestSentAlert.new
                    store_sent.info_request = info_request
                    store_sent.user = info_request.user
                    store_sent.alert_type = 'survey_1'
                    store_sent.info_request_event_id = info_request.info_request_events[0].id

                    sent_to << info_request.user_id

                    RequestMailer.survey_alert(info_request).deliver_now
                    store_sent.save!
                end
            end
        end

        module OverrideClassMethods
            def alert_new_response_reminders
                super
                alert_survey if AlaveteliConfiguration::send_survey_mails
            end
        end
    end

    # Add survey methods to RequestMailer
    RequestMailer.class_eval do
        include SurveyMethods

        class << self
            # Class methods are spilt between two modules because of a RSpec
            # mock issue.
            # We're using `include` to allow the `alert_survey` method to still
            # be mocked in our specs.
            # Using `prepend` to allows us to override a method and call `super`
            # to run the original implementation of the method in Alaveteli core
            include SurveyMethods::ClassMethods
            prepend SurveyMethods::OverrideClassMethods
        end
    end

    User.class_eval do

      def can_send_survey?
        active? && !survey.already_done?
      end

    end

    ContactValidator.class_eval do
      attr_accessor :understand

      validates_acceptance_of :understand,
                              :message => N_("Please confirm that you " \
                                             "understand that ImamoPravoZnati " \
                                             "is not run by the government, " \
                                             "and the ImamoPravoZnati " \
                                             "volunteers cannot help you " \
                                             "with personal matters relating " \
                                             "to government services.")
    end

    InfoRequest::TitleValidation.module_eval do
      def generic_foi_title?
        title =~ /(PPI|ZPPI|pravo na pristup informacijama|pristup informacijama|pristup informaciji|ponovna uporaba|ponovnu uporabu)/i
      end
    end

end
