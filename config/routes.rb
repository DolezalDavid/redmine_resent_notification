# Redmine Resent Notification Plugin Routes

post 'projects/:project_id/issues/:issue_id/resend_notification', 
     to: 'resent_notifications#resend_issue', 
     as: 'resend_issue_notification'

post 'projects/:project_id/journals/:journal_id/resend_notification', 
     to: 'resent_notifications#resend_journal', 
     as: 'resend_journal_notification'

# Direct routes (bez project_id)
post 'issues/:issue_id/resend_notification', 
     to: 'resent_notifications#resend_issue'

post 'journals/:journal_id/resend_notification', 
     to: 'resent_notifications#resend_journal'

# Admin routes
get 'admin/resent_notifications', 
    to: 'resent_notifications#index',
    as: 'admin_resent_notifications'
