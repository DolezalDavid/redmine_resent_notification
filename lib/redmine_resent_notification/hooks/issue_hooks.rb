module RedmineResentNotification
  module Hooks
    class IssueHooks < Redmine::Hook::ViewListener
      
      def view_issues_show_description_bottom(context = {})
        issue = context[:issue]
        return '' unless issue
        return '' unless User.current.allowed_to?(:resend_notifications, issue.project)

        link_content = sprite_icon('mail', l(:button_resend_notification))
        
        content_tag(:div, class: 'contextual resent-notification-actions') do
          link_to(
            link_content,
            resend_issue_notification_path(project_id: issue.project, issue_id: issue),
            method: :post,
            class: 'icon icon-email',
            title: l(:button_resend_notification),
            data: { 
              confirm: l(:text_resend_notification_confirmation),
              remote: true
            }
          )
        end
      end
      
      def view_issues_context_menu_end(context = {})
        issues = context[:issues]
        return '' unless issues&.any?
        
        # Check permissions for all issues
        return '' unless issues.all? { |issue| User.current.allowed_to?(:resend_notifications, issue.project) }
        
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

      def view_layouts_base_html_head(context = {})
        # Include plugin stylesheets
        stylesheet_link_tag('redmine-resent-notification', plugin: 'redmine_resent_notification') +
        javascript_include_tag('redmine-resent-notification', plugin: 'redmine_resent_notification')
      end
    end
  end
end
