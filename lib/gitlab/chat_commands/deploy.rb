module Gitlab
  module ChatCommands
    class Deploy < BaseCommand
      include Gitlab::Routing.url_helpers

      def self.match(text)
        /\Adeploy\s+(?<from>.*)\s+to+\s+(?<to>.*)\z/.match(text)
      end

      def self.help_message
        'deploy <environment> to <target-environment>'
      end

      def self.available?(project)
        project.builds_enabled?
      end

      def self.allowed?(project, user)
        can?(user, :create_deployment, project)
      end

      def execute(match)
        from = match[:from]
        to = match[:to]

        actions = find_actions(from, to)
        return unless actions.present?

        if actions.one?
          play!(from, to, actions.first)
        else
          Result.new(:error, 'Too many actions defined')
        end
      end

      private

      def play!(from, to, action)
        new_action = action.play(current_user)

        Result.new(:success, "Deployment from #{from} to #{to} started. Follow the progress: #{url(new_action)}.")
      end

      def find_actions(from, to)
        environment = project.environments.find_by(name: from)
        return unless environment

        environment.actions_for(to).select(&:starts_environment?)
      end

      def url(subject)
        polymorphic_url(
          [ subject.project.namespace.becomes(Namespace), subject.project, subject ])
      end
    end
  end
end
