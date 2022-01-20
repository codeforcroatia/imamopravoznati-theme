# This file is executed in the Rails environment by rails-post-install

# Create PIN and address for users db
def column_exists?(table, column)
  # XXX ActiveRecord 3 includes "column_exists?" method on `connection`
  return ActiveRecord::Base.connection.columns(table.to_sym).collect{|c| c.name.to_sym}.include? column
end

if !column_exists?(:users, :national_id_number) || !column_exists?(:users, :address)
  require File.expand_path '../db/migrate/ipz_add_address_and_pin_to_user', __FILE__
  IpzAddAddressAndPinToUser.up
end

# Create any necessary global Censor rules
require File.expand_path(File.dirname(__FILE__) + '/lib/censor_rules')
