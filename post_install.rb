# This file is executed in the Rails environment by rails-post-install

# DB migration
def column_exists?(table, column)
    # "column_exists?" method on `connection`
    return ActiveRecord::Base.connection.columns(table.to_sym).collect{|c| c.name.to_sym}.include? column
end

# add the Panama-specific fields to the User model
if !column_exists?(:users, :national_id_number)
    require File.expand_path '../db/migrate/ipz_add_extra_fields_to_user', __FILE__
    IpzThemeAddExtraFieldsToUser.up
end

# add the user_type default to User model
if User.new.user_type.nil?
    require File.expand_path '../db/migrate/ipz_default_user_type_to_individual', __FILE__
    IpzThemeDefaultUserTypeToIndividual.up
end

# Create any necessary global Censor rules
require File.expand_path(File.dirname(__FILE__) + '/lib/censor_rules')
