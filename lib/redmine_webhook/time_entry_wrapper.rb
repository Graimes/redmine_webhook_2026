module RedmineWebhook
  class TimeEntryWrapper
    def initialize(time_entry)
      @time_entry = time_entry
    end

    def to_hash
      {
        :id => @time_entry.id,
        :hours => @time_entry.hours,
        :comments => @time_entry.comments,
        :spent_on => @time_entry.spent_on,
        :created_on => @time_entry.created_on,
        :updated_on => @time_entry.updated_on,
        :project => RedmineWebhook::ProjectWrapper.new(@time_entry.project).to_hash,
        :issue_id => @time_entry.issue_id,
        :activity => enumeration_hash(@time_entry.activity),
        :user => RedmineWebhook::AuthorWrapper.new(@time_entry.user).to_hash,
        :author => RedmineWebhook::AuthorWrapper.new(@time_entry.author).to_hash
      }
    end

    private

    def enumeration_hash(enumeration)
      return nil unless enumeration

      {:id => enumeration.id, :name => enumeration.name}
    end
  end
end
