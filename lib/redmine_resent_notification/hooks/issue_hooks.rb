module RedmineResentNotification
  module Hooks
    class IssueHooks < Redmine::Hook::ViewListener
      
      def view_issues_show_description_bottom(context = {})
        Rails.logger.info "=== HOOK: view_issues_show_description_bottom called ==="
        
        issue = context[:issue]
        Rails.logger.info "=== HOOK: Issue found: #{issue&.id} ==="
        
        return '' unless issue
        
        user_allowed = User.current.allowed_to?(:resend_notifications, issue.project)
        Rails.logger.info "=== HOOK: User #{User.current.login} allowed: #{user_allowed} ==="
        
        return '' unless user_allowed

        # Zkusit jednoduché HTML místo sprite_icon
        html_content = %{
          <div class="contextual" style="float: right; margin-top: -2em;">
            <a href="/issues/#{issue.id}/resend_notification" 
               data-method="post" 
               class="icon icon-email" 
               style="background: #f0f0f0; padding: 5px 10px; margin-left: 5px; text-decoration: none; border-radius: 3px;"
               onclick="return confirm('Opravdu chcete znovu odeslat notifikaci?')">
              📧 Odeslat znovu
            </a>
          </div>
        }.html_safe
        
        Rails.logger.info "=== HOOK: Returning HTML ==="
        html_content
      end
      
      def view_layouts_base_html_head(context = {})
        Rails.logger.info "=== HOOK: view_layouts_base_html_head called ==="
        stylesheet_link_tag('redmine-resent-notification', plugin: 'redmine_resent_notification')
      end
    end
  end
end
