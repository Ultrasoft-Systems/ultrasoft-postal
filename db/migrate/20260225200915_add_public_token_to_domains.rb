# frozen_string_literal: true

class AddPublicTokenToDomains < ActiveRecord::Migration[7.0]

  def change
    add_column :domains, :public_token, :string
    add_index :domains, :public_token, unique: true

    reversible do |dir|
      dir.up do
        Domain.find_each do |domain|
          domain.update_column(:public_token, SecureRandom.alphanumeric(24))
        end
      end
    end
  end

end
