module RedmineHook
  class IssueHooks < Redmine::Hook::ViewListener
    
    def view_issues_show_description_bottom(context={})
      issue = context[:issue]
      return '' unless issue
      return '' unless User.current.allowed_to?(:resend_notifications, issue.project)

      content_tag(:div, class: 'contextual resent-notification-actions') do
        link_to(
          sprite_icon('mail', l(:button_resend_notification)),
          resend_issue_notification_path(issue),
          method: :post,
          class: 'icon icon-email',
          title: l(:button_resend_notification),
          data: { confirm: l(:text_resend_notification_confirmation) }
        )
      end
    end
    
    def view_issues_context_menu_end(context={})
      issues = context[:issues]
      return '' unless issues&.any?
      
      # Pouze pokud má uživatel oprávnění pro všechny issues
      return '' unless issues.all? { |issue| User.current.allowed_to?(:resend_notifications, issue.project) }
      
      # Pro bulk actions
      content_tag(:li) do
        link_to(
          sprite_icon('mail', l(:button_resend_notifications_bulk)),
          '#',
          class: 'icon icon-email',
          onclick: 'bulkResentNotifications(); return false;',
          title: l(:button_resend_notifications_bulk)
        )
      end
    end
  end
end
