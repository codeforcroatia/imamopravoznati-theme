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
        # just fall back to the core calculation
        return self.base_calculate_status
    end

    # Mixin methods for InfoRequest
    module ClassMethods
    end
end

module RequestControllerCustomStates

    def theme_describe_state(info_request)
    end

end
