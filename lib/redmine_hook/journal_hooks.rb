module RedmineHook
  class JournalHooks < Redmine::Hook::ViewListener
    
    def view_issues_history_journal_bottom(context={})
      journal = context[:journal]
      return '' unless journal
      return '' unless User.current.allowed_to?(:resend_notifications, journal.issue.project)

      content_tag(:div, class: 'journal-link') do
        link_to(
          sprite_icon('mail', l(:button_resend_journal_notification), size: '14'),
          resend_journal_notification_path(journal),
          method: :post,
          class: 'icon icon-email journal-resend',
          title: l(:button_resend_journal_notification),
          data: { confirm: l(:text_resend_journal_confirmation) }
        )
      end
    end
  end
end
