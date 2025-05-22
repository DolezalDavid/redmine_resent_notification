require 'redmine'
require_relative 'lib/redmine_resent_notification/version'

Redmine::Plugin.register :redmine_resent_notification do
  name 'Redmine Resent Notification Plugin'
  author 'Váš tým'
  description 'Moderní plugin pro opětovné odeslání emailových notifikací v Redmine 6.x s podporou SVG ikon a pokročilých funkcí.'
  version RedmineResentNotification::VERSION
  url 'https://github.com/your-org/redmine_resent_notification'
  author_url 'https://your-website.com'

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
