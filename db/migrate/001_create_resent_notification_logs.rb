class CreateResentNotificationLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :resent_notification_logs do |t|
      t.references :issue, null: false, foreign_key: true, index: true
      t.references :journal, null: true, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.string :notification_type, null: false
      t.integer :recipient_count, default: 0
      t.string :ip_address, limit: 45
      t.text :user_agent
      t.timestamps null: false
    end

    add_index :resent_notification_logs, [:issue_id, :created_at], name: 'index_resent_logs_on_issue_and_date'
    add_index :resent_notification_logs, [:user_id, :created_at], name: 'index_resent_logs_on_user_and_date'
    add_index :resent_notification_logs, :notification_type
    add_index :resent_notification_logs, :created_at
  end
end
