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
    def is_foi_motion_page?
      controller.controller_name == 'help' && controller.action_name == 'foi_motion'
    end
    def is_unhappy_page?
      controller.controller_name == 'help' && controller.action_name == 'unhappy'
    end
  end

  InfoRequestHelper.class_eval do
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

  def status_text_waiting_response_very_overdue(info_request, _opts = {})
    str = _('Response to this request is <strong>long overdue</strong>.')
    str += ' '
    if info_request.public_body.not_subject_to_law?
      str += _('Although not legally required to do so, we would have ' \
               'expected {{public_body_link}} to have responded by now',
               public_body_link: public_body_link(info_request.public_body))
    else
      str += _('By law, {{public_body_link}} should normally have responded ' \
               '<strong>promptly</strong> and',
               public_body_link: public_body_link(info_request.public_body))
      str += ' '
      str += _('by')
      str += ' '
    end
    str += content_tag(:strong,
                       simple_date(info_request.date_response_required_by))
    str += ' '
    str += "("
    str += details_help_link(info_request.public_body)
    str += ")."

    unless info_request.is_external?
      str += ' '
      str += _('You can <strong>complain</strong> by')
      str += ' '
      str += link_to _('requesting an internal review'),
                    new_request_followup_path(request_id: info_request.id) +
                    '?internal_review=1'
      str += '.'
    end

    str
  end
end

end
