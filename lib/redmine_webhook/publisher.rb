module RedmineWebhook
  class Publisher
    class << self
      def publish(project, request_body)
        webhook_scope(project).where.not(:url => [nil, '']).pluck(:url).each do |url|
          RedmineWebhook::DeliveryJob.perform_later(url, request_body)
        end
      end

      private

      def webhook_scope(project)
        project_webhooks = Webhook.where(:project_id => project.id)
        project_webhooks.exists? ? project_webhooks : Webhook.where(:project_id => 0)
      end
    end
  end
end
