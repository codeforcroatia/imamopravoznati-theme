# -*- encoding : utf-8 -*-
class IpzAddAddressAndDobToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :address, :string
    add_column :users, :national_id_number, :string
  end

  def self.down
    remove_column :users, :national_id_number
    remove_column :users, :address
  end
end
