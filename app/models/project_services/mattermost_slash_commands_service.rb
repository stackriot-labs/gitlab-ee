class MattermostSlashCommandsService < ChatService
  include TriggersHelper

  prop_accessor :token

  def can_test?
    false
  end

  def title
    'Mattermost Command'
  end

  def description
    "Perform common operations on GitLab in Mattermost"
  end

  def to_param
    'mattermost_slash_commands'
  end

  def help
    "This service allows you to use slash commands with your Mattermost installation.<br/>
    To setup this Service you need to create a new <b>Slash commands</b> in your Mattermost integration panel.<br/>
    <br/>
    Create integration with URL #{service_trigger_url(self)} and enter the token below."
  end

  def fields
    [
      { type: 'text', name: 'token', placeholder: '' }
    ]
  end

  def trigger(params)
    return nil unless valid_token?(params[:token])

    user = find_chat_user(params)
    unless user
      url = authorize_chat_name_url(params)
      return Mattermost::Presenter.authorize_chat_name(url)
    end

    Gitlab::ChatCommands::Command.new(project, user, params).execute
  end

  private

  def find_chat_user(params)
    ChatNames::FindUserService.new(self, params).execute
  end

  def authorize_chat_name_url(params)
    ChatNames::AuthorizeUserService.new(self, params).execute
  end
end
