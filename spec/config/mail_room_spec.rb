require 'spec_helper'

describe 'mail_room.yml' do
  let(:config_path)   { 'config/mail_room.yml' }
  let(:configuration) { YAML.load(ERB.new(File.read(config_path)).result) }
  before(:each) { clear_raw_config }
  after(:each) { clear_raw_config }

  context 'when incoming email is disabled' do
    before do
      ENV['MAIL_ROOM_GITLAB_CONFIG_FILE'] = Rails.root.join('spec/fixtures/mail_room_disabled.yml').to_s
      Gitlab::MailRoom.reset_config!
    end

    after do
      ENV['MAIL_ROOM_GITLAB_CONFIG_FILE'] = nil
    end

    it 'contains no configuration' do
      expect(configuration[:mailboxes]).to be_nil
    end
  end

  context 'when incoming email is enabled' do
    let(:redis_config) { Rails.root.join('spec/fixtures/config/redis_new_format_host.yml') }
    let(:gitlab_redis) { Gitlab::Redis.new(Rails.env) }

    before do
      ENV['MAIL_ROOM_GITLAB_CONFIG_FILE'] = Rails.root.join('spec/fixtures/mail_room_enabled.yml').to_s
      Gitlab::MailRoom.reset_config!
    end

    after do
      ENV['MAIL_ROOM_GITLAB_CONFIG_FILE'] = nil
    end

    it 'contains the intended configuration' do
      stub_const('Gitlab::Redis::CONFIG_FILE', redis_config)

      expect(configuration[:mailboxes].length).to eq(1)
      mailbox = configuration[:mailboxes].first

      expect(mailbox[:host]).to eq('imap.gmail.com')
      expect(mailbox[:port]).to eq(993)
      expect(mailbox[:ssl]).to eq(true)
      expect(mailbox[:start_tls]).to eq(false)
      expect(mailbox[:email]).to eq('gitlab-incoming@gmail.com')
      expect(mailbox[:password]).to eq('[REDACTED]')
      expect(mailbox[:name]).to eq('inbox')
      expect(mailbox[:idle_timeout]).to eq(60)

      redis_url = gitlab_redis.url
      sentinels = gitlab_redis.sentinels

      expect(mailbox[:delivery_options][:redis_url]).to be_present
      expect(mailbox[:delivery_options][:redis_url]).to eq(redis_url)

      expect(mailbox[:delivery_options][:sentinels]).to be_present
      expect(mailbox[:delivery_options][:sentinels]).to eq(sentinels)

      expect(mailbox[:arbitration_options][:redis_url]).to be_present
      expect(mailbox[:arbitration_options][:redis_url]).to eq(redis_url)

      expect(mailbox[:arbitration_options][:sentinels]).to be_present
      expect(mailbox[:arbitration_options][:sentinels]).to eq(sentinels)
    end
  end

  def clear_raw_config
    Gitlab::Redis.remove_instance_variable(:@_raw_config)
  rescue NameError
    # raised if @_raw_config was not set; ignore
  end
end
