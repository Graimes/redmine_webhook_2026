module RedmineWebhook
  class EventBuilder
    class << self
      def time_entry(action, time_entry)
        payload = {
          :event => "time_entry.#{action}",
          :action => action,
          :time_entry => RedmineWebhook::TimeEntryWrapper.new(time_entry).to_hash,
          :changes => time_entry.previous_changes.except('updated_on'),
          :url => issue_url(time_entry.issue)
        }
        payload[:issue] = RedmineWebhook::IssueWrapper.new(time_entry.issue).to_hash if time_entry.issue

        {:payload => payload}.to_json
      end

      private

      def issue_url(issue)
        return nil unless issue

        Rails.application.routes.url_helpers.issue_url(
          issue,
          :host => Setting.host_name,
          :protocol => Setting.protocol
        )
      rescue ActionController::UrlGenerationError, ArgumentError
        nil
      end
    end
  end
end
