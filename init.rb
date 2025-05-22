require 'redmine'

Redmine::Plugin.register :that_resent_notification do
  name 'Redmine Resent Notification Plugin'
  author 'David Doležal'
  description 'Modern version of That Resent Notification. It allows re-sent notification.'
  version '0.1.0'
  url 'https://github.com/DolezalDavid/redmine_resent_notification'
  author_url 'https://github.com/DolezalDavid'

  requires_redmine version_or_higher: '6.0.0'

  # Permissions
  permission :resend_notifications, {
    resent_notifications: [:resend_issue, :resend_journal]
  }, public: false

  # Settings
  settings default: {
    'notification_delay' => '0',
    'max_resends_per_day' => '10',
    'audit_log_enabled' => 'true'
  }, partial: 'settings/resent_notification_settings'
end

# Načtení hooks
require_dependency 'redmine_hook/issue_hooks'
require_dependency 'redmine_hook/journal_hooks'
