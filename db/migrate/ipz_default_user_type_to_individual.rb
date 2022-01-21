class IpzThemeDefaultUserTypeToIndividual < ActiveRecord::Migration[4.2]
  def self.up
    change_column_default :users, :user_type, "individual"
  end

  def self.down
    change_column_default :users, :user_type, nil
  end
end
