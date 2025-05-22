class ResentNotificationsController < ApplicationController
  before_action :require_admin, only: [:index]
  before_action :require_login
  before_action :find_project, except: [:index]
  before_action :authorize, except: [:index]

  def index
    Rails.logger.info "=== RESENT NOTIFICATION: Admin index accessed by #{User.current.login} ==="
    
    # Bez paginace - jen posledních 50 záznamů
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

  def resend_issue
    Rails.logger.info "=== RESENT NOTIFICATION: resend_issue called ==="
    Rails.logger.info "=== Params: #{params.inspect} ==="
    Rails.logger.info "=== Current user: #{User.current.login} ==="
    
    @issue = Issue.find(params[:issue_id])
    Rails.logger.info "=== Found issue: ##{@issue.id} - #{@issue.subject} ==="
    
    unless @issue
      Rails.logger.error "=== Issue not found ==="
      render_404
      return
    end

    # Rate limiting check
    if rate_limit_exceeded?(@issue)
      Rails.logger.warn "=== Rate limit exceeded for user #{User.current.login} ==="
      flash[:error] = l(:error_rate_limit_exceeded)
      redirect_back_or_default(issue_path(@issue))
      return
    end

    begin
      # Build recipients list
      recipients = build_recipients_list(@issue)
      Rails.logger.info "=== Recipients found: #{recipients.count} ==="
      recipients.each { |r| Rails.logger.info "=== Recipient: #{r.login} (#{r.mail}) ===" }
      
      if recipients.empty?
        Rails.logger.warn "=== No recipients found ==="
        flash[:warning] = "Nebyli nalezeni žádní příjemci pro odeslání notifikace"
        redirect_back_or_default(issue_path(@issue))
        return
      end

      # Send notifications
      success_count = 0
      Rails.logger.info "=== Starting to send notifications ==="
      
      recipients.each do |user|
        Rails.logger.info "=== Processing user: #{user.login} ==="
        
        begin
          # Zkusíme jednoduché odeslání
          Mailer.deliver_issue_edit(@issue, user)
          success_count += 1
          Rails.logger.info "=== Notification sent to #{user.login} ==="
        rescue => e
          Rails.logger.error "=== Failed to send to #{user.login}: #{e.message} ==="
        end
      end

      Rails.logger.info "=== Total notifications sent: #{success_count} ==="

      # Log the action
      log_entry = log_resent_notification(@issue, nil, 'issue', success_count)
      Rails.logger.info "=== Audit log created: #{log_entry&.id} ==="

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
    Rails.logger.info "=== RESENT NOTIFICATION: resend_journal called ==="
    Rails.logger.info "=== Params: #{params.inspect} ==="
    
    @journal = Journal.find(params[:journal_id])
    @issue = @journal.issue

    unless @journal && @issue
      Rails.logger.error "=== Journal or issue not found ==="
      render_404
      return
    end

    Rails.logger.info "=== Found journal: #{@journal.id} for issue ##{@issue.id} ==="

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
      Rails.logger.info "=== Recipients found: #{recipients.count} ==="
      
      if recipients.empty?
        Rails.logger.warn "=== No recipients found ==="
        flash[:warning] = "Nebyli nalezeni žádní příjemci"
        redirect_back_or_default(issue_path(@issue))
        return
      end

      # Send journal notifications
      success_count = 0
      recipients.each do |user|
        begin
          Mailer.deliver_issue_edit(@issue, user, @journal)
          success_count += 1
          Rails.logger.info "=== Journal notification sent to #{user.login} ==="
        rescue => e
          Rails.logger.error "=== Failed to send journal notification to #{user.login}: #{e.message} ==="
        end
      end

      Rails.logger.info "=== Total journal notifications sent: #{success_count} ==="

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
    Rails.logger.info "=== Finding project from params: #{params.inspect} ==="
    @project = case
              when params[:project_id].present?
                Project.find(params[:project_id])
              when params[:issue_id].present?
                Issue.find(params[:issue_id]).project
              when params[:journal_id].present?
                Journal.find(params[:journal_id]).issue.project
              end
    Rails.logger.info "=== Found project: #{@project&.name} ==="
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "=== Project find error: #{e.message} ==="
    render_404
  end

  def build_recipients_list(issue)
    Rails.logger.info "=== Building recipients list for issue ##{issue.id} ==="
    recipients = Set.new
    
    # Issue author
    if issue.author&.active?
      recipients.add(issue.author)
      Rails.logger.info "=== Added author: #{issue.author.login} ==="
    end
    
    # Current assignee
    if issue.assigned_to.is_a?(User) && issue.assigned_to.active?
      recipients.add(issue.assigned_to)
      Rails.logger.info "=== Added assignee: #{issue.assigned_to.login} ==="
    end
    
    # Watchers
    issue.watcher_users.select(&:active?).each do |user|
      recipients.add(user)
      Rails.logger.info "=== Added watcher: #{user.login} ==="
    end
    
    # Project members (jen ti s Admin rolí pro testování)
    issue.project.users.select(&:active?).each do |user|
      if user.admin? || user.login == 'admin'
        recipients.add(user)
        Rails.logger.info "=== Added admin user: #{user.login} ==="
      end
    end
    
    final_recipients = recipients.to_a.compact
    Rails.logger.info "=== Final recipients count: #{final_recipients.count} ==="
    final_recipients
  end

  def rate_limit_exceeded?(issue)
    max_resends = Setting.plugin_redmine_resent_notification['max_resends_per_day'].to_i
    return false if max_resends <= 0
    
    today_count = ResentNotificationLog.where(
      user: User.current,
      issue: issue,
      created_at: Date.current.all_day
    ).count
    
    Rails.logger.info "=== Rate limit check: #{today_count}/#{max_resends} for user #{User.current.login} ==="
    
    today_count >= max_resends
  rescue => e
    Rails.logger.error "=== Error in rate_limit_exceeded: #{e.message} ==="
    false
  end

  def log_resent_notification(issue, journal, type, recipient_count)
    return unless Setting.plugin_redmine_resent_notification['audit_log_enabled'] == 'true'
    
    log_entry = ResentNotificationLog.create!(
      issue: issue,
      journal: journal,
      user: User.current,
      notification_type: type,
      recipient_count: recipient_count,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
    
    Rails.logger.info "=== Audit log entry created: ID #{log_entry.id} ==="
    log_entry
  rescue => e
    Rails.logger.error "=== Error creating audit log: #{e.message} ==="
    nil
  end
end
