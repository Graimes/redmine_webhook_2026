module RedmineWebhook
  module TimeEntryPatch
    extend ActiveSupport::Concern

    included do
      attr_accessor :redmine_webhook_skip

      after_create_commit :redmine_webhook_publish_created
      after_update_commit :redmine_webhook_publish_updated
      after_destroy_commit :redmine_webhook_publish_deleted
    end

    private

    def redmine_webhook_publish_created
      redmine_webhook_publish('created')
    end

    def redmine_webhook_publish_updated
      redmine_webhook_publish('updated')
    end

    def redmine_webhook_publish_deleted
      redmine_webhook_publish('deleted')
    end

    def redmine_webhook_publish(action)
      return if redmine_webhook_skip

      RedmineWebhook::Publisher.publish(
        project,
        RedmineWebhook::EventBuilder.time_entry(action, self)
      )
    end
  end
end
