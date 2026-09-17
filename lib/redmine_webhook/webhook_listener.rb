module RedmineWebhook
  class WebhookListener < Redmine::Hook::Listener

    def skip_webhooks(context)
      return true unless context[:request]
      return true if context[:request].headers['X-Skip-Webhooks']

      false
    end

    def controller_issues_new_after_save(context = {})
      return if skip_webhooks(context)
      issue = context[:issue]
      controller = context[:controller]
      RedmineWebhook::Publisher.publish(
        issue.project,
        issue_to_json(issue, controller)
      )
    end

    def controller_issues_edit_after_save(context = {})
      return if skip_webhooks(context)
      journal = context[:journal]
      controller = context[:controller]
      issue = context[:issue]
      RedmineWebhook::Publisher.publish(
        issue.project,
        journal_to_json(issue, journal, controller)
      )
    end

    def controller_issues_bulk_edit_after_save(context = {})
      return if skip_webhooks(context)
      journal = context[:journal]
      controller = context[:controller]
      issue = context[:issue]
      RedmineWebhook::Publisher.publish(
        issue.project,
        journal_to_json(issue, journal, controller)
      )
    end

    def controller_timelog_edit_before_save(context = {})
      context[:time_entry].redmine_webhook_skip = true if skip_webhooks(context)
    end

    def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context = {})
      issue = context[:issue]
      journal = issue.current_journal
      RedmineWebhook::Publisher.publish(
        issue.project,
        journal_to_json(issue, journal, nil)
      )
    end

    private
    def issue_to_json(issue, controller)
      {
        :payload => {
          :action => 'opened',
          :issue => RedmineWebhook::IssueWrapper.new(issue).to_hash,
          :url => controller.issue_url(issue)
        }
      }.to_json
    end

    def journal_to_json(issue, journal, controller)
      {
        :payload => {
          :action => 'updated',
          :issue => RedmineWebhook::IssueWrapper.new(issue).to_hash,
          :journal => RedmineWebhook::JournalWrapper.new(journal).to_hash,
          :url => controller.nil? ? 'not yet implemented' : controller.issue_url(issue)
        }
      }.to_json
    end

  end
end
