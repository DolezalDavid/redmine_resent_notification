# Redmine Resent Notification Plugin

A modern plugin for Redmine 6.x that enables resending email notifications.

## Features

- ✅ Resend notifications for issues and journal entries  
- ✅ SVG icons compatible with Redmine 6.x  
- ✅ Czech and English localization  
- ✅ Rate limiting and audit log  
- ✅ Admin dashboard with statistics  
- ✅ Responsive design  

## Installation

1. Clone into the `plugins` directory  
2. Run `bundle install --without development test`  
3. Run `bundle exec rake redmine:plugins:migrate RAILS_ENV=production`  
4. Run `bundle exec rake icons:plugin:generate NAME=redmine_resent_notification RAILS_ENV=production`  
5. Restart Redmine  

## Requirements

- Redmine 6.0.x or later  
- Ruby 3.1 or later  

## License

MIT

## 📋 Plugin Installation

```bash
# 1. Create plugin directory
mkdir -p /path/to/redmine/plugins/redmine_resent_notification

# 2. Copy files into the directory structure shown above

# 3. Install dependencies
cd /path/to/redmine
bundle install --without development test

# 4. Run migrations
bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# 5. (Optional) Generate SVG icons
bundle exec rake icons:plugin:generate NAME=redmine_resent_notification RAILS_ENV=production

# 6. Restart Redmine
touch tmp/restart.txt
