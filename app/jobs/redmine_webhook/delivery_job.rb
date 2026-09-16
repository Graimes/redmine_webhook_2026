require 'openssl'

module RedmineWebhook
  class DeliveryError < StandardError; end

  class DeliveryJob < ActiveJob::Base
    queue_as :default

    retry_on DeliveryError, :wait => 5.seconds, :attempts => 3

    def perform(url, request_body)
      response = Faraday.post do |request|
        request.url url
        request.headers['Content-Type'] = 'application/json'
        signature_headers(request_body).each do |name, value|
          request.headers[name] = value
        end
        request.body = request_body
      end

      return if response.status.to_i.between?(200, 299)

      raise DeliveryError, "Webhook returned HTTP #{response.status} for #{url}"
    rescue DeliveryError
      raise
    rescue StandardError => error
      raise DeliveryError, "Webhook request failed for #{url}: #{error.message}"
    end

    private

    def signature_headers(request_body)
      secret = ENV['REDMINE_WEBHOOK_SECRET'].to_s
      return {} if secret.empty?

      timestamp = Time.now.to_i.to_s
      delivery_id = job_id
      signed_content = [timestamp, delivery_id, request_body].join('.')
      digest = OpenSSL::HMAC.hexdigest('SHA256', secret, signed_content)

      {
        'X-Redmine-Webhook-Id' => delivery_id,
        'X-Redmine-Webhook-Timestamp' => timestamp,
        'X-Redmine-Webhook-Signature' => "sha256=#{digest}"
      }
    end
  end
end
