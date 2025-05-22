class ResentNotificationsController < ApplicationController
  before_action :require_login
  before_action :find_project, except: [:index]
  before_action :authorize, except: [:index]

  def index
    # Admin stránka pro overview
    @resent_logs = ResentNotificationLog.includes(:user, :issue, :journal)
                                       .order(created_at: :desc)
                                       .limit(50)
  end

  def resend_issue
    @issue = Issue.find(params[:issue_id])
    
    if @issue.nil?
      render_404
      return
    end

    # Rate limiting check
    if rate_limit_exceeded?(@issue)
      flash[:error] = l(:error_rate_limit_exceeded)
      redirect_back_or_default(issue_path(@issue))
      return
    end

    begin
      # Sestavení seznamu příjemců
      recipients = build_recipients_list(@issue)
      
      # Odeslání notifikací
      recipients.each do |user|
        Mailer.deliver_issue_edit(@issue, user) if user.mail_notification_enabled?(@issue)
      end

      # Logging
      log_resent_notification(@issue, nil, 'issue', recipients.size)

      flash[:notice] = l(:notice_notification_resent_successfully, count: recipients.size)
    rescue => e
      Rails.logger.error "Failed to resend notification: #{e.message}"
      flash[:error] = l(:error_notification_resend_failed)
    end

    redirect_back_or_default(issue_path(@issue))
  end

  def resend_journal
    @journal = Journal.find(params[:journal_id])
    @issue = @journal.issue

    if @journal.nil? || @issue.nil?
      render_404
      return
    end

    # Rate limiting check
    if rate_limit_exceeded?(@issue)
      flash[:error] = l(:error_rate_limit_exceeded)
      redirect_back_or_default(issue_path(@issue))
      return
    end

    begin
      # Sestavení seznamu příjemců
      recipients = build_recipients_list(@issue)
      
      # Odeslání notifikací s journal
      recipients.each do |user|
        Mailer.deliver_issue_edit(@issue, user, @journal) if user.mail_notification_enabled?(@issue)
      end

      # Logging
      log_resent_notification(@issue, @journal, 'journal', recipients.size)

      flash[:notice] = l(:notice_journal_notification_resent, count: recipients.size)
    rescue => e
      Rails.logger.error "Failed to resend journal notification: #{e.message}"
      flash[:error] = l(:error_journal_notification_failed)
    end

    redirect_back_or_default(issue_path(@issue))
  end

  private

  def find_project
    @project = params[:project_id] ? Project.find(params[:project_id]) : nil
    @project ||= params[:issue_id] ? Issue.find(params[:issue_id]).project : nil
    @project ||= params[:journal_id] ? Journal.find(params[:journal_id]).issue.project : nil
  end

  def build_recipients_list(issue)
    recipients = []
    
    # Author
    recipients << issue.author if issue.author&.active?
    
    # Assignee
    recipients << issue.assigned_to if issue.assigned_to&.is_a?(User) && issue.assigned_to&.active?
    
    # Watchers
    recipients += issue.watcher_users.select(&:active?)
    
    # Project members with notification preference
    recipients += issue.project.users.select { |u| u.active? && u.mail_notification_enabled?(issue) }
    
    recipients.uniq.compact
  end

  def rate_limit_exceeded?(issue)
    return false unless Setting.plugin_that_resent_notification['max_resends_per_day'].to_i > 0
    
    max_resends = Setting.plugin_that_resent_notification['max_resends_per_day'].to_i
    today_count = ResentNotificationLog.where(
      user: User.current,
      issue: issue,
      created_at: Date.current.beginning_of_day..Date.current.end_of_day
    ).count
    
    today_count >= max_resends
  end

  def log_resent_notification(issue, journal, type, recipient_count)
    return unless Setting.plugin_that_resent_notification['audit_log_enabled'] == 'true'
    
    ResentNotificationLog.create!(
      issue: issue,
      journal: journal,
      user: User.current,
      notification_type: type,
      recipient_count: recipient_count,
      ip_address: request.remote_ip
    )
  end
end
