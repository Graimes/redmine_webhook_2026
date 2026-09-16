require File.expand_path('../../test_helper', __FILE__)
require 'active_job/test_helper'

class WebhookTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  fixtures :projects, :users, :issues, :trackers, :issue_statuses,
           :enumerations, :custom_fields, :custom_values, :watchers,
           :time_entries

  setup do
    Webhook.delete_all
    clear_enqueued_jobs
  end

  test 'project webhook takes precedence over global webhook' do
    project = Project.find(1)
    Webhook.create!(:project_id => 0, :url => 'http://receiver:8080/global')
    Webhook.create!(:project => project, :url => 'http://receiver:8080/project')

    assert_enqueued_with(
      :job => RedmineWebhook::DeliveryJob,
      :args => ['http://receiver:8080/project', '{"payload":{}}']
    ) do
      RedmineWebhook::Publisher.publish(project, '{"payload":{}}')
    end
    assert_equal 1, enqueued_jobs.size
  end

  test 'global webhook is used when project has no webhook' do
    project = Project.find(1)
    Webhook.create!(:project_id => 0, :url => 'http://receiver:8080/global')

    assert_enqueued_with(
      :job => RedmineWebhook::DeliveryJob,
      :args => ['http://receiver:8080/global', '{"payload":{}}']
    ) do
      RedmineWebhook::Publisher.publish(project, '{"payload":{}}')
    end
  end

  test 'time entry event contains issue users and changes' do
    time_entry = TimeEntry.find(1)
    time_entry.hours = 5.5
    time_entry.save!

    payload = JSON.parse(RedmineWebhook::EventBuilder.time_entry('updated', time_entry))['payload']

    assert_equal 'time_entry.updated', payload['event']
    assert_equal 'updated', payload['action']
    assert_equal 1, payload.dig('time_entry', 'id')
    assert_equal 1, payload.dig('issue', 'id')
    assert_equal 2, payload.dig('time_entry', 'user', 'id')
    assert_equal [4.25, 5.5], payload.dig('changes', 'hours')
  end

  test 'updating a time entry enqueues webhook after a successful commit' do
    project = Project.find(1)
    Webhook.create!(:project => project, :url => 'http://receiver:8080/time-entry')
    time_entry = TimeEntry.find(1)

    assert_enqueued_jobs 1, :only => RedmineWebhook::DeliveryJob do
      time_entry.update!(:comments => 'Updated work log')
    end

    request_body = enqueued_jobs.last.fetch(:args).last
    assert_equal 'time_entry.updated', JSON.parse(request_body).dig('payload', 'event')
  end

  test 'skip header marker suppresses time entry webhook' do
    project = Project.find(1)
    Webhook.create!(:project => project, :url => 'http://receiver:8080/time-entry')
    time_entry = TimeEntry.find(1)
    time_entry.redmine_webhook_skip = true

    assert_no_enqueued_jobs :only => RedmineWebhook::DeliveryJob do
      time_entry.update!(:comments => 'Updated without webhook')
    end
  end
end
