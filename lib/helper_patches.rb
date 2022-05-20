# Load our helpers
require 'helpers/user_helper'
require 'helpers/donation_helper'

Rails.configuration.to_prepare do
  ActionView::Base.send(:include, UserHelper)
  ActionView::Base.send(:include, DonationHelper)

  ApplicationHelper.class_eval do
    def is_contact_page?
      controller.controller_name == 'help' && controller.action_name == 'contact'
    end
  end

  ModuleHelper.class_eval do
    def status_text_internal_review(info_request, opts = {})
      str = _('Waiting for an <strong>internal review</strong> by ' \
              '{{public_body_link}} of their handling of this request.',
              :public_body_link => public_body_link(info_request.public_body))
      str += ' '
      if info_request.public_body.not_subject_to_law?
        str += _('Although not legally required to do so, we would have ' \
                 'expected {{public_body_link}} to have responded by ',
                 :public_body_link => public_body_link(info_request.public_body))
      else
        str += _('By law, {{public_body_link}} should normally have responded ' \
                 '<strong>promptly</strong> and',
                 :public_body_link => public_body_link(info_request.public_body))
        str += ' '
        str += _('by')
        str += ' '
      end
      str += content_tag(:strong,
                         simple_date(info_request.date_response_required_by))
      str += ' '
      str += "("
      str += details_help_link(info_request.public_body)
      str += ")"
    end
  end

end
