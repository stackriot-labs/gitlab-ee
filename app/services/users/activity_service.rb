module Users
  class ActivityService
    def initialize(author, activity)
      @author = author.respond_to?(:user) ? author.user : author
      @activity = activity
    end

    def execute
      return unless @author && @author.is_a?(User)

      record_activity
    end

    private

    def record_activity
      user_activity.touch unless Gitlab::Geo.secondary?

      Rails.logger.debug("Recorded activity: #{@activity} for User ID: #{@author.id} (username: #{@author.username}")
    end

    def user_activity
      UserActivity.find_or_initialize_by(user: @author)
    end
  end
end
