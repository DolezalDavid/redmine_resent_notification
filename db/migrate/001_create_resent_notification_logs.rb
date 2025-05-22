class CreateResentNotificationLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :resent_notification_logs do |t|
      # Použití integer místo references pro kompatibilitu s Redmine
      t.integer :issue_id, null: false
      t.integer :journal_id, null: true  
      t.integer :user_id, null: false
      t.string :notification_type, null: false
      t.integer :recipient_count, default: 0
      t.string :ip_address, limit: 45
      t.text :user_agent
      t.timestamps null: false
    end

    # Manuální přidání foreign keys s explicitním typem
    add_foreign_key :resent_notification_logs, :issues, column: :issue_id
    add_foreign_key :resent_notification_logs, :journals, column: :journal_id
    add_foreign_key :resent_notification_logs, :users, column: :user_id

    # Indexy
    add_index :resent_notification_logs, :issue_id
    add_index :resent_notification_logs, :journal_id
    add_index :resent_notification_logs, :user_id
    add_index :resent_notification_logs, [:issue_id, :created_at], name: 'index_resent_logs_on_issue_and_date'
    add_index :resent_notification_logs, [:user_id, :created_at], name: 'index_resent_logs_on_user_and_date'
    add_index :resent_notification_logs, :notification_type
    add_index :resent_notification_logs, :created_at
  end
end
