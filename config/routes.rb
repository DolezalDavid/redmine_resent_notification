# Plugin's routes
post 'resent_notifications/:issue_id/resend_issue', 
     to: 'resent_notifications#resend_issue', 
     as: 'resend_issue_notification'

post 'resent_notifications/:journal_id/resend_journal', 
     to: 'resent_notifications#resend_journal', 
     as: 'resend_journal_notification'

get 'admin/resent_notifications', 
    to: 'resent_notifications#index',
    as: 'admin_resent_notifications'
