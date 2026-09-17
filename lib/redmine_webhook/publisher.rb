module RedmineWebhook
  class Publisher
    class << self
      def publish(project, request_body)
        urls_for(project).each do |url|
          begin
            RedmineWebhook::DeliveryJob.perform_later(url, request_body)
          rescue => error
            Rails.logger.error error
          end
        end
      end

      def urls_for(project)
        project_ids = [project.id] + project.ancestors.reverse.map(&:id)
        urls = project_ids.flat_map do |project_id|
          Webhook.where(:project_id => project_id)
                 .where.not(:url => [nil, ''])
                 .order(:id)
                 .pluck(:url)
        end
        if urls.empty?
          urls = Webhook.where(:project_id => 0)
                        .where.not(:url => [nil, ''])
                        .order(:id)
                        .pluck(:url)
        end

        urls.uniq
      end
    end
  end
end
