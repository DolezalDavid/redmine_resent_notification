require 'redmine'
require_relative 'lib/redmine_resent_notification/version'

Redmine::Plugin.register :redmine_resent_notification do
  name 'Redmine Resent Notification Plugin'
  author 'David Doležal'
  description 'A modern plugin for resending email notifications in Redmine 6.x, featuring SVG icon support and advanced functionality.'
  version '0.1.0'
  url 'https://github.com/DolezalDavid/redmine_resent_notification'
  author_url 'https://github.com/DolezalDavid'

  requires_redmine version_or_higher: '6.0.0'

  # Permissions
  permission :resend_notifications, {
    resent_notifications: [:index, :resend_issue, :resend_journal]
  }, public: false, read: true

  # Admin menu
  menu :admin_menu, :resent_notifications,
       { controller: 'resent_notifications', action: 'index' },
       caption: :label_resent_notifications,
       html: { class: 'icon icon-email' }

  # Settings
  settings default: {
    'notification_delay' => '0',
    'max_resends_per_day' => '10',
    'audit_log_enabled' => 'true',
    'allowed_roles' => []
  }, partial: 'settings/resent_notification_settings'

  # Project module
  project_module :resent_notifications do
    permission :resend_notifications, {
      resent_notifications: [:resend_issue, :resend_journal]
    }
  end
end

# Load hooks
Dir[File.join(File.dirname(__FILE__), 'lib', 'redmine_resent_notification', 'hooks', '*.rb')].each do |file|
  require file
end
