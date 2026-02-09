# -*- encoding : utf-8 -*-
# See `doc/THEMES.md` for more explanation of this file
# This example adds a "transferred" state to requests.

module InfoRequestCustomStates

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Work out what the situation of the request is. In addition to
  # values of self.described_state, in base Alaveteli can return
  # these (calculated) values:
  #   waiting_classification
  #   waiting_response_overdue
  #   waiting_response_very_overdue
  def theme_calculate_status
    return "waiting_classification" if awaiting_description

    waiting_response =
      described_state == "waiting_response" ||
      described_state == "deadline_extended"

    return described_state unless waiting_response

    very_overdue_after = date_very_overdue_after
    response_required_by = date_response_required_by

    if very_overdue_after &&
      Time.zone.now.to_date > very_overdue_after.to_date
      return "waiting_response_very_overdue"
    end

    if response_required_by &&
      Time.zone.now.to_date > response_required_by.to_date
      return "waiting_response_overdue"
    end

    return "deadline_extended" if has_extended_deadline?

    "waiting_response"
  end

  # Mixin methods for InfoRequest
  module ClassMethods
    def theme_display_status(status)
      if status == 'referred'
        _("Referred.")
      elsif status == 'transferred'
        _("Transferred.")
      elsif status == 'payment_requested'
        _("Payment requested.")
      elsif status == 'deadline_extended'
        _("Deadline extended.")
      elsif status == 'correction_asked'
        _("Asked for correction.")
      else
        raise _("unknown status ") + status
      end
    end

    def theme_extra_states
      return ['referred',
          'transferred',
          'payment_requested',
          'correction_asked',
          'deadline_extended']
    end
  end
end

module RequestControllerCustomStates

  def theme_describe_state(info_request)
    case info_request.calculate_status
    when 'referred'
      flash[:notice] = _(
        "Thank you for letting us know! Hopefully your appeal process with Information Commissioner will be finished soon and positive to your satisfaction."
      )
      redirect_to unhappy_url(info_request)

    when 'transferred'
      flash[:notice] = _(
        "Original authority that received your request has transferred your request to a different public body. By law, new receiving authority should respond."
      )
      redirect_to request_url(
        request_id: info_request.id,
        request_url_title: info_request.url_title
      )

    when 'payment_requested'
      flash[:notice] = _(
        "Authority has requested you to pay material expenses incurred by the provision of information."
      )
      redirect_to request_url(
        request_id: info_request.id,
        request_url_title: info_request.url_title
      )

    when 'deadline_extended'
      flash[:notice] = _(
        "Hopefully your wait isn't too long. By law, you should get a response 30 days after they initially received your request."
      )
      redirect_to request_url(
        request_id: info_request.id,
        request_url_title: info_request.url_title
      )

    when 'correction_asked'
      flash[:notice] = _(
        "Hopefully your wait isn't too long. By law, you should get a response 15 days after they received your request for correction."
      )
      redirect_to request_url(
        request_id: info_request.id,
        request_url_title: info_request.url_title
      )

    else
      raise "unknown calculate_status #{info_request.calculate_status}"
    end
  end


end

# This file is required to exist (even if empty)
