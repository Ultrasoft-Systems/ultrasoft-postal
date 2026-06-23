# frozen_string_literal: true

class CreateAPITokens < ActiveRecord::Migration[7.1]

  def change
    create_table :api_tokens do |t|
      t.string :token, null: false
      t.string :name, null: false
      t.string :scope, null: false, default: "server"
      t.text :permissions
      t.integer :user_id
      t.integer :organization_id
      t.integer :server_id
      t.datetime :last_used_at
      t.datetime :expires_at
      t.datetime :revoked_at
      t.string :uuid
      t.timestamps
    end

    add_index :api_tokens, :token, unique: true
    add_index :api_tokens, :uuid, unique: true
    add_index :api_tokens, :user_id
    add_index :api_tokens, :organization_id
    add_index :api_tokens, :server_id
  end

end
