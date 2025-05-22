class ResentNotificationsController < ApplicationController
  before_action :require_admin, only: [:index]
  before_action :require_login
  before_action :find_project, except: [:index]
  before_action :authorize, except: [:index]

  def index
    @logs = ResentNotificationLog.includes(:user, :issue, :journal)
                                 .order(created_at: :desc)
                                 .page(params[:page])
                                 .per_page(25)
    
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
  end

  def resend_issue
    @issue = Issue.find(params[:issue_id])
    
    unless @issue
      render_404
      return
    end

    # Rate limiting check
    if rate_limit_exceeded?(@issue)
      respond_to do |format|
        format.html do
          flash[:error] = l(:error_rate_limit_exceeded)
          redirect_back_or_default(issue_path(@issue))
        end
        format.json { render json: { error: l(:error_rate_limit_exceeded) }, status: :too_many_requests }
      end
      return
    end

    begin
      # Build recipients list
      recipients = build_recipients_list(@issue)
      
      if recipients.empty?
        flash[:warning] = l(:warning_no_recipients_found)
        redirect_back_or_default(issue_path(@issue))
        return
      end

      # Send notifications
      success_count = 0
      recipients.each do |user|
        if user.mail_notification_enabled?(@issue)
          Mailer.deliver_issue_edit(@issue, user)
          success_count += 1
        end
      end

      # Log the action
      log_resent_notification(@issue, nil, 'issue', success_count)

      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_notification_resent_successfully, count: success_count)
          redirect_back_or_default(issue_path(@issue))
        end
        format.json { render json: { message: l(:notice_notification_resent_successfully, count: success_count), count: success_count } }
      end

    rescue => e
      Rails.logger.error "Failed to resend issue notification: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.html do
          flash[:error] = l(:error_notification_resend_failed)
          redirect_back_or_default(issue_path(@issue))
        end
        format.json { render json: { error: l(:error_notification_resend_failed) }, status: :internal_server_error }
      end
    end
  end

  def resend_journal
    @journal = Journal.find(params[:journal_id])
    @issue = @journal.issue

    unless @journal && @issue
      render_404
      return
    end

    # Rate limiting check
    if rate_limit_exceeded?(@issue)
      respond_to do |format|
        format.html do
          flash[:error] = l(:error_rate_limit_exceeded)
          redirect_back_or_default(issue_path(@issue))
        end
        format.json { render json: { error: l(:error_rate_limit_exceeded) }, status: :too_many_requests }
      end
      return
    end

    begin
      # Build recipients list
      recipients = build_recipients_list(@issue)
      
      if recipients.empty?
        flash[:warning] = l(:warning_no_recipients_found)
        redirect_back_or_default(issue_path(@issue))
        return
      end

      # Send journal notifications
      success_count = 0
      recipients.each do |user|
        if user.mail_notification_enabled?(@issue)
          Mailer.deliver_issue_edit(@issue, user, @journal)
          success_count += 1
        end
      end

      # Log the action
      log_resent_notification(@issue, @journal, 'journal', success_count)

      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_journal_notification_resent, count: success_count)
          redirect_back_or_default(issue_path(@issue))
        end
        format.json { render json: { message: l(:notice_journal_notification_resent, count: success_count), count: success_count } }
      end

    rescue => e
      Rails.logger.error "Failed to resend journal notification: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.html do
          flash[:error] = l(:error_journal_notification_failed)
          redirect_back_or_default(issue_path(@issue))
        end
        format.json { render json: { error: l(:error_journal_notification_failed) }, status: :internal_server_error }
      end
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
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def build_recipients_list(issue)
    recipients = Set.new
    
    # Issue author
    recipients.add(issue.author) if issue.author&.active?
    
    # Current assignee
    if issue.assigned_to.is_a?(User) && issue.assigned_to.active?
      recipients.add(issue.assigned_to)
    end
    
    # Watchers
    issue.watcher_users.select(&:active?).each { |user| recipients.add(user) }
    
    # Project members who want notifications
    issue.project.users.select(&:active?).each do |user|
      recipients.add(user) if user.mail_notification_enabled?(issue)
    end
    
    recipients.to_a.compact
  end

  def rate_limit_exceeded?(issue)
    max_resends = Setting.plugin_redmine_resent_notification['max_resends_per_day'].to_i
    return false if max_resends <= 0
    
    today_count = ResentNotificationLog.where(
      user: User.current,
      issue: issue,
      created_at: Date.current.all_day
    ).count
    
    today_count >= max_resends
  end

  def log_resent_notification(issue, journal, type, recipient_count)
    return unless Setting.plugin_redmine_resent_notification['audit_log_enabled'] == 'true'
    
    ResentNotificationLog.create!(
      issue: issue,
      journal: journal,
      user: User.current,
      notification_type: type,
      recipient_count: recipient_count,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end
end
