module RedmineResentNotification
  module Hooks
    class JournalHooks < Redmine::Hook::ViewListener
      
      def view_issues_history_journal_bottom(context = {})
        journal = context[:journal]
        return '' unless journal
        return '' unless User.current.allowed_to?(:resend_notifications, journal.issue.project)

        link_content = sprite_icon('mail', l(:button_resend_journal_notification), size: '14')
        
        content_tag(:div, class: 'journal-link') do
          link_to(
            link_content,
            resend_journal_notification_path(
              project_id: journal.issue.project, 
              journal_id: journal
            ),
            method: :post,
            class: 'icon icon-email journal-resend',
            title: l(:button_resend_journal_notification),
            data: { 
              confirm: l(:text_resend_journal_confirmation),
              remote: true
            }
          )
        end
      end
    end
  end
end
