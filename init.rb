if Rails.try(:autoloaders).try(:zeitwerk_enabled?)
  Rails.autoloaders.main.push_dir File.dirname(__FILE__) + '/lib/redmine_webhook'
  RedmineWebhook::ProjectsHelperPatch
  RedmineWebhook::WebhookListener
  RedmineWebhook::TimeEntryPatch
else
  require "redmine_webhook"
end

apply_time_entry_patch = proc do
  TimeEntry.include(RedmineWebhook::TimeEntryPatch) unless TimeEntry < RedmineWebhook::TimeEntryPatch
end
apply_time_entry_patch.call
ActiveSupport::Reloader.to_prepare(&apply_time_entry_patch)

Redmine::Plugin.register :redmine_webhook do
  name 'Redmine Webhook plugin'
  author 'suer / graimes + llm'
  description 'Posts signed webhooks for issue and time entry events'
  version '0.1.1'
  url 'https://github.com/Graimes/redmine_webhook_2026'
  author_url 'http://d.hatena.ne.jp/suer'
  project_module :webhooks do
    permission :manage_hook, {:webhook_settings => [:index, :show, :update, :create, :destroy]}, :require => :member
  end
end
