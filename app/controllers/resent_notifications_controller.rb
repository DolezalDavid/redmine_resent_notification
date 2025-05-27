class ResentNotificationsController < ApplicationController
  before_action :require_admin, only: [:index]
  before_action :require_login
  before_action :find_project, except: [:index]
  before_action :authorize, except: [:index]

  def index
    Rails.logger.info "=== RESENT NOTIFICATION: Admin index accessed by #{User.current.login} ==="
    
    begin
      @logs = ResentNotificationLog.includes(:user, :issue, :journal)
                                   .order(created_at: :desc)
                                   .limit(50)
      
      @stats = {
        total_resends: ResentNotificationLog.count,
        today_resends: ResentNotificationLog.where(created_at: Date.current.all_day).count,
        this_week_resends: ResentNotificationLog.where(created_at: 1.week.ago..Time.current).count,
        top_users: ResentNotificationLog.joins(:user)
                                       .group('users.login')
                                       .count
                                       .sort_by { |_, count| -count }
                                       .first(5)
      }
      
      Rails.logger.info "=== RESENT NOTIFICATION: Stats #{@stats} ==="
    rescue => e
      Rails.logger.error "=== ERROR in index: #{e.message} ==="
      @logs = []
      @stats = { total_resends: 0, today_resends: 0, this_week_resends: 0, top_users: [] }
    end
  end

  def resend_issue
    Rails.logger.error "=== CONTROLLER CALLED: resend_issue for issue #{params[:issue_id]} by #{User.current.login} ==="
    
    begin
      @issue = Issue.find(params[:issue_id])
      Rails.logger.error "=== Found issue: ##{@issue.id} - #{@issue.subject} ==="
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "=== Issue not found ==="
      render_404
      return
    end

    # Rate limiting check
    if rate_limit_exceeded?(@issue)
      Rails.logger.warn "=== Rate limit exceeded for user #{User.current.login} ==="
      flash[:error] = "Překročen denní limit odeslání notifikací"
      redirect_back_or_default(issue_path(@issue))
      return
    end

    begin
      # Build recipients list
      recipients = build_recipients_list(@issue)
      Rails.logger.error "=== Recipients found: #{recipients.count} ==="
      
      if recipients.empty?
        Rails.logger.warn "=== No recipients found ==="
        flash[:warning] = "Nebyli nalezeni žádní příjemci pro odeslání notifikace"
        redirect_back_or_default(issue_path(@issue))
        return
      end

      # Send notifications
      success_count = 0
      Rails.logger.error "=== Starting to send notifications ==="
      
      recipients.each do |user|
        Rails.logger.error "=== TRYING to send to: #{user.login} ==="
        begin
          Mailer.issue_add(user, @issue).deliver
          success_count += 1
          Rails.logger.error "=== SUCCESS for: #{user.login} ==="
        rescue => e
          Rails.logger.error "=== ERROR for #{user.login}: #{e.message} ==="
        end
      end

      Rails.logger.error "=== Total notifications sent: #{success_count} ==="

      # Log the action
      log_entry = log_resent_notification(@issue, nil, 'issue', success_count)
      Rails.logger.error "=== Audit log created: #{log_entry&.id} ==="

      flash[:notice] = "Notifikace byla úspěšně odeslána #{success_count} příjemcům"
      redirect_back_or_default(issue_path(@issue))

    rescue => e
      Rails.logger.error "=== MAJOR ERROR in resend_issue: #{e.message} ==="
      Rails.logger.error e.backtrace.join("\n")
      
      flash[:error] = "Nepodařilo se znovu odeslat notifikaci"
      redirect_back_or_default(issue_path(@issue))
    end
  end

  def resend_journal
    Rails.logger.error "=== CONTROLLER: resend_journal called ==="
    
    begin
      @journal = Journal.find(params[:journal_id])
      @issue = @journal.issue
      Rails.logger.error "=== Found journal: #{@journal.id} for issue ##{@issue.id} ==="
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "=== Journal or issue not found ==="
      render_404
      return
    end

    # Rate limiting check
    if rate_limit_exceeded?(@issue)
      Rails.logger.warn "=== Rate limit exceeded ==="
      flash[:error] = "Překročen denní limit odeslání notifikací"
      redirect_back_or_default(issue_path(@issue))
      return
    end

    begin
      # Build recipients list
      recipients = build_recipients_list(@issue)
      Rails.logger.error "=== Recipients found: #{recipients.count} ==="
      
      if recipients.empty?
        Rails.logger.warn "=== No recipients found ==="
        flash[:warning] = "Nebyli nalezeni žádní příjemci"
        redirect_back_or_default(issue_path(@issue))
        return
      end

      # Send journal notifications
      success_count = 0
      recipients.each do |user|
        Rails.logger.error "=== TRYING to send journal to: #{user.login} ==="
        begin
          # Pro journal používáme issue_edit s journal objektem
          Mailer.issue_edit(user, @journal).deliver
          success_count += 1
          Rails.logger.error "=== SUCCESS journal for: #{user.login} ==="
        rescue => e
          Rails.logger.error "=== ERROR journal for #{user.login}: #{e.message} ==="
        end
      end

      Rails.logger.error "=== Total journal notifications sent: #{success_count} ==="

      # Log the action
      log_resent_notification(@issue, @journal, 'journal', success_count)

      flash[:notice] = "Notifikace záznamu byla úspěšně odeslána #{success_count} příjemcům"
      redirect_back_or_default(issue_path(@issue))

    rescue => e
      Rails.logger.error "=== ERROR in resend_journal: #{e.message} ==="
      Rails.logger.error e.backtrace.join("\n")
      
      flash[:error] = "Nepodařilo se znovu odeslat notifikaci záznamu"
      redirect_back_or_default(issue_path(@issue))
    end
  end

  private

  def find_project
    @project = case
              when params[:project_id].present?
                Project.find(params[:project_id])
              when params[:issue_id].present?
                Issue.find(params[:issue_id]).project
              when params[:journal_id].present?
                Journal.find(params[:journal_id]).issue.project
              end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "=== Project find error: #{e.message} ==="
    render_404
  end

  def build_recipients_list(issue)
    Rails.logger.error "=== BUILDING RECIPIENTS for issue ##{issue.id} ==="
    recipients = Set.new
    
    # Issue author
    if issue.author&.active?
      recipients.add(issue.author)
      Rails.logger.error "=== ✅ Added author: #{issue.author.login} ==="
    end
    
    # Current assignee
    if issue.assigned_to.is_a?(User) && issue.assigned_to.active?
      recipients.add(issue.assigned_to)
      Rails.logger.error "=== ✅ Added assignee: #{issue.assigned_to.login} ==="
    end
    
    # Watchers
    begin
      watchers = issue.watcher_users.select(&:active?)
      watchers.each do |user|
        recipients.add(user)
        Rails.logger.error "=== ✅ Added watcher: #{user.login} ==="
      end
    rescue => e
      Rails.logger.error "=== ERROR getting watchers: #{e.message} ==="
    end
    
    # Project members
    begin
      project_members = issue.project.users.select(&:active?)
      project_members.each do |user|
        recipients.add(user)
        Rails.logger.error "=== ✅ Added project member: #{user.login} ==="
      end
    rescue => e
      Rails.logger.error "=== ERROR getting project members: #{e.message} ==="
    end
    
    # Fallback - current user
    if User.current.active?
      recipients.add(User.current)
      Rails.logger.error "=== ✅ Added current user: #{User.current.login} ==="
    end
    
    final_recipients = recipients.to_a.compact
    Rails.logger.error "=== FINAL RECIPIENTS COUNT: #{final_recipients.count} ==="
    
    final_recipients
  end

  def rate_limit_exceeded?(issue)
    begin
      max_resends = Setting.plugin_redmine_resent_notification['max_resends_per_day'].to_i
      return false if max_resends <= 0
      
      today_count = ResentNotificationLog.where(
        user: User.current,
        issue: issue,
        created_at: Date.current.all_day
      ).count
      
      Rails.logger.error "=== Rate limit check: #{today_count}/#{max_resends} for user #{User.current.login} ==="
      
      today_count >= max_resends
    rescue => e
      Rails.logger.error "=== Error in rate_limit_exceeded: #{e.message} ==="
      false
    end
  end

  def log_resent_notification(issue, journal, type, recipient_count)
    return unless Setting.plugin_redmine_resent_notification['audit_log_enabled'] == 'true'
    
    begin
      log_entry = ResentNotificationLog.create!(
        issue: issue,
        journal: journal,
        user: User.current,
        notification_type: type,
        recipient_count: recipient_count,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      
      Rails.logger.error "=== Audit log entry created: ID #{log_entry.id} ==="
      log_entry
    rescue => e
      Rails.logger.error "=== Error creating audit log: #{e.message} ==="
      nil
    end
  end
end
