require File.expand_path('../../test_helper', __FILE__)
require 'net/http'
require 'openssl'

class DeliveryTest < ActiveSupport::TestCase
  setup do
    skip 'WEBHOOK_RECEIVER_URL is not configured' unless ENV['WEBHOOK_RECEIVER_URL']

    request(Net::HTTP::Delete.new('/events'))
  end

  test 'delivery job sends JSON to the configured endpoint' do
    body = '{"payload":{"event":"delivery.test"}}'

    RedmineWebhook::DeliveryJob.perform_now("#{receiver_url}/webhook", body)
    events = JSON.parse(request(Net::HTTP::Get.new('/events')).body)

    assert_equal 1, events.length
    assert_equal '/webhook', events.first.fetch('path')
    assert_equal 'application/json', events.first.dig('headers', 'Content-Type')
    assert_equal JSON.parse(body), events.first.fetch('body')

    headers = events.first.fetch('headers')
    delivery_id = headers.fetch('X-Redmine-Webhook-Id')
    timestamp = headers.fetch('X-Redmine-Webhook-Timestamp')
    signed_content = [timestamp, delivery_id, body].join('.')
    expected_signature = OpenSSL::HMAC.hexdigest(
      'SHA256',
      ENV.fetch('REDMINE_WEBHOOK_SECRET'),
      signed_content
    )

    assert_match(/\A[0-9a-f-]{36}\z/, delivery_id)
    assert_in_delta Time.now.to_i, timestamp.to_i, 5
    assert_equal "sha256=#{expected_signature}", headers.fetch('X-Redmine-Webhook-Signature')
  end

  test 'delivery remains unsigned when secret is not configured' do
    configured_secret = ENV.delete('REDMINE_WEBHOOK_SECRET')
    body = '{"payload":{"event":"delivery.unsigned"}}'

    RedmineWebhook::DeliveryJob.perform_now("#{receiver_url}/unsigned", body)
    event = JSON.parse(request(Net::HTTP::Get.new('/events')).body).first

    refute event.fetch('headers').key?('X-Redmine-Webhook-Signature')
  ensure
    ENV['REDMINE_WEBHOOK_SECRET'] = configured_secret if configured_secret
  end

  private

  def receiver_url
    ENV.fetch('WEBHOOK_RECEIVER_URL')
  end

  def request(http_request)
    uri = URI(receiver_url)
    Net::HTTP.start(uri.host, uri.port) {|http| http.request(http_request)}
  end
end
