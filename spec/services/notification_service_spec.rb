require 'spec_helper'

describe NotificationService, services: true do
  let(:notification) { NotificationService.new }

  around(:each) do |example|
    perform_enqueued_jobs do
      example.run
    end
  end

  shared_examples 'notifications for new mentions' do
    def send_notifications(*new_mentions)
      reset_delivered_emails!
      notification.send(notification_method, mentionable, new_mentions, @u_disabled)
    end

    it 'sends no emails when no new mentions are present' do
      send_notifications
      should_not_email_anyone
    end

    it 'emails new mentions with a watch level higher than participant' do
      send_notifications(@u_watcher, @u_participant_mentioned, @u_custom_global)
      should_only_email(@u_watcher, @u_participant_mentioned, @u_custom_global)
    end

    it 'does not email new mentions with a watch level equal to or less than participant' do
      send_notifications(@u_participating, @u_mentioned)
      should_not_email_anyone
    end
  end

  describe 'Keys' do
    describe '#new_key' do
      let!(:key) { create(:personal_key) }

      it { expect(notification.new_key(key)).to be_truthy }

      it 'sends email to key owner' do
        expect{ notification.new_key(key) }.to change{ ActionMailer::Base.deliveries.size }.by(1)
      end
    end
  end

  describe 'Email' do
    describe '#new_email' do
      let!(:email) { create(:email) }

      it { expect(notification.new_email(email)).to be_truthy }

      it 'sends email to email owner' do
        expect{ notification.new_email(email) }.to change{ ActionMailer::Base.deliveries.size }.by(1)
      end
    end
  end

  describe 'Notes' do
    context 'issue note' do
      let(:project) { create(:empty_project, :private) }
      let(:issue) { create(:issue, project: project, assignee: create(:user)) }
      let(:mentioned_issue) { create(:issue, assignee: issue.assignee) }
      let(:note) { create(:note_on_issue, noteable: issue, project_id: issue.project_id, note: '@mention referenced, @outsider also') }

      before do
        build_team(note.project)
        project.add_master(issue.author)
        project.add_master(issue.assignee)
        project.add_master(note.author)
        create(:note_on_issue, noteable: issue, project_id: issue.project_id, note: '@subscribed_participant cc this guy')
        update_custom_notification(:new_note, @u_guest_custom, project)
        update_custom_notification(:new_note, @u_custom_global)
      end

      describe '#new_note' do
        it do
          add_users_with_subscription(note.project, issue)

          # Ensure create SentNotification by noteable = issue 6 times, not noteable = note
          expect(SentNotification).to receive(:record).with(issue, any_args).exactly(8).times

          reset_delivered_emails!

          notification.new_note(note)

          should_email(@u_watcher)
          should_email(note.noteable.author)
          should_email(note.noteable.assignee)
          should_email(@u_custom_global)
          should_email(@u_mentioned)
          should_email(@subscriber)
          should_email(@watcher_and_subscriber)
          should_email(@subscribed_participant)
          should_not_email(@u_guest_custom)
          should_not_email(@u_guest_watcher)
          should_not_email(note.author)
          should_not_email(@u_participating)
          should_not_email(@u_disabled)
          should_not_email(@unsubscriber)
          should_not_email(@u_outsider_mentioned)
          should_not_email(@u_lazy_participant)
        end

        it 'filters out "mentioned in" notes' do
          mentioned_note = SystemNoteService.cross_reference(mentioned_issue, issue, issue.author)

          expect(Notify).not_to receive(:note_issue_email)
          notification.new_note(mentioned_note)
        end

        context 'participating' do
          context 'by note' do
            before do
              reset_delivered_emails!
              note.author = @u_lazy_participant
              note.save
              notification.new_note(note)
            end

            it { should_not_email(@u_lazy_participant) }
          end
        end
      end

      describe 'new note on issue in project that belongs to a group' do
        let(:group) { create(:group) }

        before do
          note.project.namespace_id = group.id
          note.project.group.add_user(@u_watcher, GroupMember::MASTER)
          note.project.group.add_user(@u_custom_global, GroupMember::MASTER)
          note.project.save

          @u_watcher.notification_settings_for(note.project).participating!
          @u_watcher.notification_settings_for(note.project.group).global!
          update_custom_notification(:new_note, @u_custom_global)
          reset_delivered_emails!
        end

        it do
          notification.new_note(note)

          should_email(note.noteable.author)
          should_email(note.noteable.assignee)
          should_email(@u_mentioned)
          should_email(@u_custom_global)
          should_not_email(@u_guest_custom)
          should_not_email(@u_guest_watcher)
          should_not_email(@u_watcher)
          should_not_email(note.author)
          should_not_email(@u_participating)
          should_not_email(@u_disabled)
          should_not_email(@u_lazy_participant)
        end
      end
    end

    context 'confidential issue note' do
      let(:project) { create(:empty_project, :public) }
      let(:author) { create(:user) }
      let(:assignee) { create(:user) }
      let(:non_member) { create(:user) }
      let(:member) { create(:user) }
      let(:guest) { create(:user) }
      let(:admin) { create(:admin) }
      let(:confidential_issue) { create(:issue, :confidential, project: project, author: author, assignee: assignee) }
      let(:note) { create(:note_on_issue, noteable: confidential_issue, project: project, note: "#{author.to_reference} #{assignee.to_reference} #{non_member.to_reference} #{member.to_reference} #{admin.to_reference}") }
      let(:guest_watcher) { create_user_with_notification(:watch, "guest-watcher-confidential") }

      it 'filters out users that can not read the issue' do
        project.add_developer(member)
        project.add_guest(guest)

        expect(SentNotification).to receive(:record).with(confidential_issue, any_args).exactly(4).times

        reset_delivered_emails!

        notification.new_note(note)

        should_not_email(non_member)
        should_not_email(guest)
        should_not_email(guest_watcher)
        should_email(author)
        should_email(assignee)
        should_email(member)
        should_email(admin)
      end
    end

    context 'issue note mention' do
      let(:project) { create(:empty_project, :public) }
      let(:issue) { create(:issue, project: project, assignee: create(:user)) }
      let(:mentioned_issue) { create(:issue, assignee: issue.assignee) }
      let(:note) { create(:note_on_issue, noteable: issue, project_id: issue.project_id, note: '@all mentioned') }

      before do
        build_team(note.project)
        note.project.add_master(note.author)
        reset_delivered_emails!
      end

      describe '#new_note' do
        it 'notifies the team members' do
          notification.new_note(note)

          # Notify all team members
          note.project.team.members.each do |member|
            # User with disabled notification should not be notified
            next if member.id == @u_disabled.id
            # Author should not be notified
            next if member.id == note.author.id
            should_email(member)
          end

          should_email(@u_guest_watcher)
          should_email(note.noteable.author)
          should_email(note.noteable.assignee)
          should_not_email(note.author)
          should_email(@u_mentioned)
          should_not_email(@u_disabled)
          should_email(@u_not_mentioned)
        end

        it 'filters out "mentioned in" notes' do
          mentioned_note = SystemNoteService.cross_reference(mentioned_issue, issue, issue.author)

          expect(Notify).not_to receive(:note_issue_email)
          notification.new_note(mentioned_note)
        end
      end
    end

    context 'project snippet note' do
      let(:project) { create(:empty_project, :public) }
      let(:snippet) { create(:project_snippet, project: project, author: create(:user)) }
      let(:note) { create(:note_on_project_snippet, noteable: snippet, project_id: snippet.project.id, note: '@all mentioned') }

      before do
        build_team(note.project)
        note.project.add_master(note.author)
        reset_delivered_emails!
      end

      describe '#new_note' do
        it 'notifies the team members' do
          notification.new_note(note)

          # Notify all team members
          note.project.team.members.each do |member|
            # User with disabled notification should not be notified
            next if member.id == @u_disabled.id
            # Author should not be notified
            next if member.id == note.author.id
            should_email(member)
          end

          # it emails custom global users on mention
          should_email(@u_custom_global)

          should_email(@u_guest_watcher)
          should_email(note.noteable.author)
          should_not_email(note.author)
          should_email(@u_mentioned)
          should_not_email(@u_disabled)
          should_email(@u_not_mentioned)
        end
      end
    end

    context 'commit note' do
      let(:project) { create(:project, :public) }
      let(:note) { create(:note_on_commit, project: project) }

      before do
        build_team(note.project)
        reset_delivered_emails!
        allow_any_instance_of(Commit).to receive(:author).and_return(@u_committer)
        update_custom_notification(:new_note, @u_guest_custom, project)
        update_custom_notification(:new_note, @u_custom_global)
      end

      describe '#new_note, #perform_enqueued_jobs' do
        it do
          notification.new_note(note)
          should_email(@u_guest_watcher)
          should_email(@u_custom_global)
          should_email(@u_guest_custom)
          should_email(@u_committer)
          should_email(@u_watcher)
          should_not_email(@u_mentioned)
          should_not_email(note.author)
          should_not_email(@u_participating)
          should_not_email(@u_disabled)
          should_not_email(@u_lazy_participant)
        end

        it do
          note.update_attribute(:note, '@mention referenced')
          notification.new_note(note)

          should_email(@u_guest_watcher)
          should_email(@u_committer)
          should_email(@u_watcher)
          should_email(@u_mentioned)
          should_not_email(note.author)
          should_not_email(@u_participating)
          should_not_email(@u_disabled)
          should_not_email(@u_lazy_participant)
        end

        it do
          @u_committer = create_global_setting_for(@u_committer, :mention)
          notification.new_note(note)
          should_not_email(@u_committer)
        end
      end
    end

    context "merge request diff note" do
      let(:project) { create(:project) }
      let(:user) { create(:user) }
      let(:merge_request) { create(:merge_request, source_project: project, assignee: user) }
      let(:note) { create(:diff_note_on_merge_request, project: project, noteable: merge_request) }

      before do
        build_team(note.project)
        project.add_master(merge_request.author)
        project.add_master(merge_request.assignee)
      end

      describe '#new_note' do
        it "records sent notifications" do
          # Ensure create SentNotification by noteable = merge_request 6 times, not noteable = note
          expect(SentNotification).to receive(:record_note).with(note, any_args).exactly(3).times.and_call_original

          notification.new_note(note)

          expect(SentNotification.last.position).to eq(note.position)
        end
      end
    end
  end

  describe 'Issues' do
    let(:group) { create(:group) }
    let(:project) { create(:empty_project, :public, namespace: group) }
    let(:another_project) { create(:empty_project, :public, namespace: group) }
    let(:issue) { create :issue, project: project, assignee: create(:user), description: 'cc @participant' }

    before do
      build_team(issue.project)
      add_users_with_subscription(issue.project, issue)
      reset_delivered_emails!
      update_custom_notification(:new_issue, @u_guest_custom, project)
      update_custom_notification(:new_issue, @u_custom_global)
    end

    describe '#new_issue' do
      it do
        notification.new_issue(issue, @u_disabled)

        should_email(issue.assignee)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_not_email(@u_mentioned)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it do
        create_global_setting_for(issue.assignee, :mention)
        notification.new_issue(issue, @u_disabled)

        should_not_email(issue.assignee)
      end

      it "emails subscribers of the issue's labels" do
        user_1 = create(:user)
        user_2 = create(:user)
        user_3 = create(:user)
        user_4 = create(:user)
        label = create(:label, project: project, issues: [issue])
        group_label = create(:group_label, group: group, issues: [issue])
        issue.reload
        label.toggle_subscription(user_1, project)
        group_label.toggle_subscription(user_2, project)
        group_label.toggle_subscription(user_3, another_project)
        group_label.toggle_subscription(user_4)

        notification.new_issue(issue, @u_disabled)

        should_email(user_1)
        should_email(user_2)
        should_not_email(user_3)
        should_email(user_4)
      end

      context 'confidential issues' do
        let(:author) { create(:user) }
        let(:assignee) { create(:user) }
        let(:non_member) { create(:user) }
        let(:member) { create(:user) }
        let(:guest) { create(:user) }
        let(:admin) { create(:admin) }
        let(:confidential_issue) { create(:issue, :confidential, project: project, title: 'Confidential issue', author: author, assignee: assignee) }

        it "emails subscribers of the issue's labels that can read the issue" do
          project.add_developer(member)
          project.add_guest(guest)

          label = create(:label, project: project, issues: [confidential_issue])
          confidential_issue.reload
          label.toggle_subscription(non_member, project)
          label.toggle_subscription(author, project)
          label.toggle_subscription(assignee, project)
          label.toggle_subscription(member, project)
          label.toggle_subscription(guest, project)
          label.toggle_subscription(admin, project)

          reset_delivered_emails!

          notification.new_issue(confidential_issue, @u_disabled)

          should_not_email(@u_guest_watcher)
          should_not_email(non_member)
          should_not_email(author)
          should_not_email(guest)
          should_email(assignee)
          should_email(member)
          should_email(admin)
        end
      end
    end

    describe '#new_mentions_in_issue' do
      let(:notification_method) { :new_mentions_in_issue }
      let(:mentionable) { issue }

      include_examples 'notifications for new mentions'
    end

    describe '#reassigned_issue' do
      before do
        update_custom_notification(:reassign_issue, @u_guest_custom, project)
        update_custom_notification(:reassign_issue, @u_custom_global)
      end

      it 'emails new assignee' do
        notification.reassigned_issue(issue, @u_disabled)

        should_email(issue.assignee)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'emails previous assignee even if he has the "on mention" notif level' do
        issue.update_attribute(:assignee, @u_mentioned)
        issue.update_attributes(assignee: @u_watcher)
        notification.reassigned_issue(issue, @u_disabled)

        should_email(@u_mentioned)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@u_custom_global)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'emails new assignee even if he has the "on mention" notif level' do
        issue.update_attributes(assignee: @u_mentioned)
        notification.reassigned_issue(issue, @u_disabled)

        expect(issue.assignee).to be @u_mentioned
        should_email(issue.assignee)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@u_custom_global)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'emails new assignee' do
        issue.update_attribute(:assignee, @u_mentioned)
        notification.reassigned_issue(issue, @u_disabled)

        expect(issue.assignee).to be @u_mentioned
        should_email(issue.assignee)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@u_custom_global)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it 'does not email new assignee if they are the current user' do
        issue.update_attribute(:assignee, @u_mentioned)
        notification.reassigned_issue(issue, @u_mentioned)

        expect(issue.assignee).to be @u_mentioned
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@u_custom_global)
        should_not_email(issue.assignee)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      context 'participating' do
        context 'by assignee' do
          before do
            issue.update_attribute(:assignee, @u_lazy_participant)
            notification.reassigned_issue(issue, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end

        context 'by note' do
          let!(:note) { create(:note_on_issue, noteable: issue, project_id: issue.project_id, note: 'anything', author: @u_lazy_participant) }

          before { notification.reassigned_issue(issue, @u_disabled) }

          it { should_email(@u_lazy_participant) }
        end

        context 'by author' do
          before do
            issue.author = @u_lazy_participant
            notification.reassigned_issue(issue, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end
      end
    end

    describe '#relabeled_issue' do
      let(:group_label_1) { create(:group_label, group: group, title: 'Group Label 1', issues: [issue]) }
      let(:group_label_2) { create(:group_label, group: group, title: 'Group Label 2') }
      let(:label_1) { create(:label, project: project, title: 'Label 1', issues: [issue]) }
      let(:label_2) { create(:label, project: project, title: 'Label 2') }
      let!(:subscriber_to_group_label_1) { create(:user) { |u| group_label_1.toggle_subscription(u, project) } }
      let!(:subscriber_1_to_group_label_2) { create(:user) { |u| group_label_2.toggle_subscription(u, project) } }
      let!(:subscriber_2_to_group_label_2) { create(:user) { |u| group_label_2.toggle_subscription(u) } }
      let!(:subscriber_to_group_label_2_on_another_project) { create(:user) { |u| group_label_2.toggle_subscription(u, another_project) } }
      let!(:subscriber_to_label_1) { create(:user) { |u| label_1.toggle_subscription(u, project) } }
      let!(:subscriber_to_label_2) { create(:user) { |u| label_2.toggle_subscription(u, project) } }

      it "emails subscribers of the issue's added labels only" do
        notification.relabeled_issue(issue, [group_label_2, label_2], @u_disabled)

        should_not_email(subscriber_to_label_1)
        should_not_email(subscriber_to_group_label_1)
        should_not_email(subscriber_to_group_label_2_on_another_project)
        should_email(subscriber_1_to_group_label_2)
        should_email(subscriber_2_to_group_label_2)
        should_email(subscriber_to_label_2)
      end

      it "doesn't send email to anyone but subscribers of the given labels" do
        notification.relabeled_issue(issue, [group_label_2, label_2], @u_disabled)

        should_not_email(issue.assignee)
        should_not_email(issue.author)
        should_not_email(@u_watcher)
        should_not_email(@u_guest_watcher)
        should_not_email(@u_participant_mentioned)
        should_not_email(@subscriber)
        should_not_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(subscriber_to_label_1)
        should_not_email(subscriber_to_group_label_1)
        should_not_email(subscriber_to_group_label_2_on_another_project)
        should_email(subscriber_1_to_group_label_2)
        should_email(subscriber_2_to_group_label_2)
        should_email(subscriber_to_label_2)
      end

      context 'confidential issues' do
        let(:author) { create(:user) }
        let(:assignee) { create(:user) }
        let(:non_member) { create(:user) }
        let(:member) { create(:user) }
        let(:guest) { create(:user) }
        let(:admin) { create(:admin) }
        let(:confidential_issue) { create(:issue, :confidential, project: project, title: 'Confidential issue', author: author, assignee: assignee) }
        let!(:label_1) { create(:label, project: project, issues: [confidential_issue]) }
        let!(:label_2) { create(:label, project: project) }

        it "emails subscribers of the issue's labels that can read the issue" do
          project.add_developer(member)
          project.add_guest(guest)

          label_2.toggle_subscription(non_member, project)
          label_2.toggle_subscription(author, project)
          label_2.toggle_subscription(assignee, project)
          label_2.toggle_subscription(member, project)
          label_2.toggle_subscription(guest, project)
          label_2.toggle_subscription(admin, project)

          reset_delivered_emails!

          notification.relabeled_issue(confidential_issue, [label_2], @u_disabled)

          should_not_email(non_member)
          should_not_email(guest)
          should_email(author)
          should_email(assignee)
          should_email(member)
          should_email(admin)
        end
      end
    end

    describe '#close_issue' do
      before do
        update_custom_notification(:close_issue, @u_guest_custom, project)
        update_custom_notification(:close_issue, @u_custom_global)
      end

      it 'sends email to issue assignee and issue author' do
        notification.close_issue(issue, @u_disabled)

        should_email(issue.assignee)
        should_email(issue.author)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      context 'participating' do
        context 'by assignee' do
          before do
            issue.update_attribute(:assignee, @u_lazy_participant)
            notification.close_issue(issue, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end

        context 'by note' do
          let!(:note) { create(:note_on_issue, noteable: issue, project_id: issue.project_id, note: 'anything', author: @u_lazy_participant) }

          before { notification.close_issue(issue, @u_disabled) }

          it { should_email(@u_lazy_participant) }
        end

        context 'by author' do
          before do
            issue.author = @u_lazy_participant
            notification.close_issue(issue, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end
      end
    end

    describe '#reopen_issue' do
      before do
        update_custom_notification(:reopen_issue, @u_guest_custom, project)
        update_custom_notification(:reopen_issue, @u_custom_global)
      end

      it 'sends email to issue assignee and issue author' do
        notification.reopen_issue(issue, @u_disabled)

        should_email(issue.assignee)
        should_email(issue.author)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_lazy_participant)
      end

      context 'participating' do
        context 'by assignee' do
          before do
            issue.update_attribute(:assignee, @u_lazy_participant)
            notification.reopen_issue(issue, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end

        context 'by note' do
          let!(:note) { create(:note_on_issue, noteable: issue, project_id: issue.project_id, note: 'anything', author: @u_lazy_participant) }

          before { notification.reopen_issue(issue, @u_disabled) }

          it { should_email(@u_lazy_participant) }
        end

        context 'by author' do
          before do
            issue.author = @u_lazy_participant
            notification.reopen_issue(issue, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end
      end
    end
  end

  describe 'Merge Requests' do
    let(:group) { create(:group) }
    let(:project) { create(:project, :public, namespace: group) }
    let(:another_project) { create(:empty_project, :public, namespace: group) }
    let(:merge_request) { create :merge_request, source_project: project, assignee: create(:user), description: 'cc @participant' }

    before do
      build_team(merge_request.target_project)
      add_users_with_subscription(merge_request.target_project, merge_request)
      update_custom_notification(:new_merge_request, @u_guest_custom, project)
      update_custom_notification(:new_merge_request, @u_custom_global)
      reset_delivered_emails!
    end

    describe '#new_merge_request' do
      before do
        update_custom_notification(:new_merge_request, @u_guest_custom, project)
        update_custom_notification(:new_merge_request, @u_custom_global)
      end

      it do
        notification.new_merge_request(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@watcher_and_subscriber)
        should_email(@u_participant_mentioned)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it "emails subscribers of the merge request's labels" do
        user_1 = create(:user)
        user_2 = create(:user)
        user_3 = create(:user)
        user_4 = create(:user)
        label = create(:label, project: project, merge_requests: [merge_request])
        group_label = create(:group_label, group: group, merge_requests: [merge_request])
        label.toggle_subscription(user_1, project)
        group_label.toggle_subscription(user_2, project)
        group_label.toggle_subscription(user_3, another_project)
        group_label.toggle_subscription(user_4)

        notification.new_merge_request(merge_request, @u_disabled)

        should_email(user_1)
        should_email(user_2)
        should_not_email(user_3)
        should_email(user_4)
      end

      context 'when the target project has approvers set' do
        let(:project_approvers) { create_list(:user, 3) }

        before do
          merge_request.target_project.update_attributes(approvals_before_merge: 1)
          project_approvers.each { |approver| create(:approver, user: approver, target: merge_request.target_project) }
        end

        it 'emails the approvers' do
          notification.new_merge_request(merge_request, @u_disabled)

          project_approvers.each { |approver| should_email(approver) }
        end

        context 'when the merge request has approvers set' do
          let(:mr_approvers) { create_list(:user, 3) }

          before do
            mr_approvers.each { |approver| create(:approver, user: approver, target: merge_request) }
          end

          it 'emails the MR approvers' do
            notification.new_merge_request(merge_request, @u_disabled)

            mr_approvers.each { |approver| should_email(approver) }
          end

          it 'does not email approvers set on the project who are not approvers of this MR' do
            notification.new_merge_request(merge_request, @u_disabled)

            project_approvers.each { |approver| should_not_email(approver) }
          end
        end
      end

      context 'participating' do
        context 'by assignee' do
          before do
            merge_request.update_attribute(:assignee, @u_lazy_participant)
            notification.new_merge_request(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end

        context 'by note' do
          let!(:note) { create(:note_on_issue, noteable: merge_request, project_id: project.id, note: 'anything', author: @u_lazy_participant) }

          before { notification.new_merge_request(merge_request, @u_disabled) }

          it { should_email(@u_lazy_participant) }
        end

        context 'by author' do
          before do
            merge_request.author = @u_lazy_participant
            merge_request.save
            notification.new_merge_request(merge_request, @u_disabled)
          end

          it { should_not_email(@u_lazy_participant) }
        end
      end
    end

    describe '#new_mentions_in_merge_request' do
      let(:notification_method) { :new_mentions_in_merge_request }
      let(:mentionable) { merge_request }

      include_examples 'notifications for new mentions'
    end

    describe '#reassigned_merge_request' do
      before do
        update_custom_notification(:reassign_merge_request, @u_guest_custom, project)
        update_custom_notification(:reassign_merge_request, @u_custom_global)
      end

      it do
        notification.reassigned_merge_request(merge_request, merge_request.author)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      context 'participating' do
        context 'by assignee' do
          before do
            merge_request.update_attribute(:assignee, @u_lazy_participant)
            notification.reassigned_merge_request(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end

        context 'by note' do
          let!(:note) { create(:note_on_issue, noteable: merge_request, project_id: project.id, note: 'anything', author: @u_lazy_participant) }

          before { notification.reassigned_merge_request(merge_request, @u_disabled) }

          it { should_email(@u_lazy_participant) }
        end

        context 'by author' do
          before do
            merge_request.author = @u_lazy_participant
            merge_request.save
            notification.reassigned_merge_request(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end
      end
    end

    describe '#relabel_merge_request' do
      let(:group_label_1) { create(:group_label, group: group, title: 'Group Label 1', merge_requests: [merge_request]) }
      let(:group_label_2) { create(:group_label, group: group, title: 'Group Label 2') }
      let(:label_1) { create(:label, project: project, title: 'Label 1', merge_requests: [merge_request]) }
      let(:label_2) { create(:label, project: project, title: 'Label 2') }
      let!(:subscriber_to_group_label_1) { create(:user) { |u| group_label_1.toggle_subscription(u, project) } }
      let!(:subscriber_1_to_group_label_2) { create(:user) { |u| group_label_2.toggle_subscription(u, project) } }
      let!(:subscriber_2_to_group_label_2) { create(:user) { |u| group_label_2.toggle_subscription(u) } }
      let!(:subscriber_to_group_label_2_on_another_project) { create(:user) { |u| group_label_2.toggle_subscription(u, another_project) } }
      let!(:subscriber_to_label_1) { create(:user) { |u| label_1.toggle_subscription(u, project) } }
      let!(:subscriber_to_label_2) { create(:user) { |u| label_2.toggle_subscription(u, project) } }

      it "emails subscribers of the merge request's added labels only" do
        notification.relabeled_merge_request(merge_request, [group_label_2, label_2], @u_disabled)

        should_not_email(subscriber_to_label_1)
        should_not_email(subscriber_to_group_label_1)
        should_not_email(subscriber_to_group_label_2_on_another_project)
        should_email(subscriber_1_to_group_label_2)
        should_email(subscriber_2_to_group_label_2)
        should_email(subscriber_to_label_2)
      end

      it "doesn't send email to anyone but subscribers of the given labels" do
        notification.relabeled_merge_request(merge_request, [group_label_2, label_2], @u_disabled)

        should_not_email(merge_request.assignee)
        should_not_email(merge_request.author)
        should_not_email(@u_watcher)
        should_not_email(@u_participant_mentioned)
        should_not_email(@subscriber)
        should_not_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_lazy_participant)
        should_not_email(subscriber_to_label_1)
        should_not_email(subscriber_to_group_label_1)
        should_not_email(subscriber_to_group_label_2_on_another_project)
        should_email(subscriber_1_to_group_label_2)
        should_email(subscriber_2_to_group_label_2)
        should_email(subscriber_to_label_2)
      end
    end

    describe '#closed_merge_request' do
      before do
        update_custom_notification(:close_merge_request, @u_guest_custom, project)
        update_custom_notification(:close_merge_request, @u_custom_global)
      end

      it do
        notification.close_mr(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      context 'participating' do
        context 'by assignee' do
          before do
            merge_request.update_attribute(:assignee, @u_lazy_participant)
            notification.close_mr(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end

        context 'by note' do
          let!(:note) { create(:note_on_issue, noteable: merge_request, project_id: project.id, note: 'anything', author: @u_lazy_participant) }

          before { notification.close_mr(merge_request, @u_disabled) }

          it { should_email(@u_lazy_participant) }
        end

        context 'by author' do
          before do
            merge_request.author = @u_lazy_participant
            merge_request.save
            notification.close_mr(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end
      end
    end

    describe '#merged_merge_request' do
      before do
        update_custom_notification(:merge_merge_request, @u_guest_custom, project)
        update_custom_notification(:merge_merge_request, @u_custom_global)
      end

      it do
        notification.merge_mr(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_email(@u_guest_watcher)
        should_email(@u_custom_global)
        should_email(@u_guest_custom)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      it "notifies the merger when merge_when_build_succeeds is true" do
        merge_request.merge_when_build_succeeds = true
        notification.merge_mr(merge_request, @u_watcher)

        should_email(@u_watcher)
      end

      it "does not notify the merger when merge_when_build_succeeds is false" do
        merge_request.merge_when_build_succeeds = false
        notification.merge_mr(merge_request, @u_watcher)

        should_not_email(@u_watcher)
      end

      context 'participating' do
        context 'by assignee' do
          before do
            merge_request.update_attribute(:assignee, @u_lazy_participant)
            notification.merge_mr(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end

        context 'by note' do
          let!(:note) { create(:note_on_issue, noteable: merge_request, project_id: project.id, note: 'anything', author: @u_lazy_participant) }

          before { notification.merge_mr(merge_request, @u_disabled) }

          it { should_email(@u_lazy_participant) }
        end

        context 'by author' do
          before do
            merge_request.author = @u_lazy_participant
            merge_request.save
            notification.merge_mr(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end
      end
    end

    describe '#reopen_merge_request' do
      before do
        update_custom_notification(:reopen_merge_request, @u_guest_custom, project)
        update_custom_notification(:reopen_merge_request, @u_custom_global)
      end

      it do
        notification.reopen_mr(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_email(@u_guest_watcher)
        should_email(@u_guest_custom)
        should_email(@u_custom_global)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      context 'participating' do
        context 'by assignee' do
          before do
            merge_request.update_attribute(:assignee, @u_lazy_participant)
            notification.reopen_mr(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end

        context 'by note' do
          let!(:note) { create(:note_on_issue, noteable: merge_request, project_id: project.id, note: 'anything', author: @u_lazy_participant) }

          before { notification.reopen_mr(merge_request, @u_disabled) }

          it { should_email(@u_lazy_participant) }
        end

        context 'by author' do
          before do
            merge_request.author = @u_lazy_participant
            merge_request.save
            notification.reopen_mr(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end
      end
    end

    describe "#resolve_all_discussions" do
      it do
        notification.resolve_all_discussions(merge_request, @u_disabled)

        should_email(merge_request.assignee)
        should_email(@u_watcher)
        should_email(@u_participant_mentioned)
        should_email(@subscriber)
        should_email(@watcher_and_subscriber)
        should_email(@u_guest_watcher)
        should_not_email(@unsubscriber)
        should_not_email(@u_participating)
        should_not_email(@u_disabled)
        should_not_email(@u_lazy_participant)
      end

      context 'participating' do
        context 'by assignee' do
          before do
            merge_request.update_attribute(:assignee, @u_lazy_participant)
            notification.resolve_all_discussions(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end

        context 'by note' do
          let!(:note) { create(:note_on_issue, noteable: merge_request, project_id: project.id, note: 'anything', author: @u_lazy_participant) }

          before { notification.resolve_all_discussions(merge_request, @u_disabled) }

          it { should_email(@u_lazy_participant) }
        end

        context 'by author' do
          before do
            merge_request.author = @u_lazy_participant
            merge_request.save
            notification.resolve_all_discussions(merge_request, @u_disabled)
          end

          it { should_email(@u_lazy_participant) }
        end
      end
    end
  end

  describe 'Projects' do
    let(:project) { create :project }

    before do
      build_team(project)
      reset_delivered_emails!
    end

    describe '#project_was_moved' do
      it do
        notification.project_was_moved(project, "gitlab/gitlab")

        should_email(@u_watcher)
        should_email(@u_participating)
        should_email(@u_lazy_participant)
        should_email(@u_custom_global)
        should_not_email(@u_guest_watcher)
        should_not_email(@u_guest_custom)
        should_not_email(@u_disabled)
      end
    end
  end

  describe 'GroupMember' do
    describe '#decline_group_invite' do
      let(:creator) { create(:user) }
      let(:group) { create(:group) }
      let(:member) { create(:user) }

      before(:each) do
        group.add_owner(creator)
        group.add_developer(member, creator)
      end

      it do
        group_member = group.members.first

        expect do
          notification.decline_group_invite(group_member)
        end.to change { ActionMailer::Base.deliveries.size }.by(1)
      end
    end
  end

  describe 'ProjectMember' do
    describe '#decline_group_invite' do
      let(:project) { create(:project) }
      let(:member) { create(:user) }

      before(:each) do
        project.add_developer(member, current_user: project.owner)
      end

      it do
        project_member = project.members.first

        expect do
          notification.decline_project_invite(project_member)
        end.to change { ActionMailer::Base.deliveries.size }.by(1)
      end
    end
  end

  context 'guest user in private project' do
    let(:private_project) { create(:empty_project, :private) }
    let(:guest) { create(:user) }
    let(:developer) { create(:user) }
    let(:assignee) { create(:user) }
    let(:merge_request) { create(:merge_request, source_project: private_project, assignee: assignee) }
    let(:merge_request1) { create(:merge_request, source_project: private_project, assignee: assignee, description: "cc @#{guest.username}") }
    let(:note) { create(:note, noteable: merge_request, project: private_project) }

    before do
      private_project.add_developer(assignee)
      private_project.add_developer(developer)
      private_project.add_guest(guest)

      ActionMailer::Base.deliveries.clear
    end

    it 'filters out guests when new note is created' do
      expect(SentNotification).to receive(:record).with(merge_request, any_args).exactly(1).times

      notification.new_note(note)

      should_not_email(guest)
      should_email(assignee)
    end

    it 'filters out guests when new merge request is created' do
      notification.new_merge_request(merge_request1, @u_disabled)

      should_not_email(guest)
      should_email(assignee)
    end

    it 'filters out guests when merge request is closed' do
      notification.close_mr(merge_request, developer)

      should_not_email(guest)
      should_email(assignee)
    end

    it 'filters out guests when merge request is reopened' do
      notification.reopen_mr(merge_request, developer)

      should_not_email(guest)
      should_email(assignee)
    end

    it 'filters out guests when merge request is merged' do
      notification.merge_mr(merge_request, developer)

      should_not_email(guest)
      should_email(assignee)
    end
  end

  def build_team(project)
    @u_watcher               = create_global_setting_for(create(:user), :watch)
    @u_participating         = create_global_setting_for(create(:user), :participating)
    @u_participant_mentioned = create_global_setting_for(create(:user, username: 'participant'), :participating)
    @u_disabled              = create_global_setting_for(create(:user), :disabled)
    @u_mentioned             = create_global_setting_for(create(:user, username: 'mention'), :mention)
    @u_committer             = create(:user, username: 'committer')
    @u_not_mentioned         = create_global_setting_for(create(:user, username: 'regular'), :participating)
    @u_outsider_mentioned    = create(:user, username: 'outsider')
    @u_custom_global         = create_global_setting_for(create(:user, username: 'custom_global'), :custom)

    # User to be participant by default
    # This user does not contain any record in notification settings table
    # It should be treated with a :participating notification_level
    @u_lazy_participant      = create(:user, username: 'lazy-participant')

    @u_guest_watcher = create_user_with_notification(:watch, 'guest_watching')
    @u_guest_custom = create_user_with_notification(:custom, 'guest_custom')

    project.add_master(@u_watcher)
    project.add_master(@u_participating)
    project.add_master(@u_participant_mentioned)
    project.add_master(@u_disabled)
    project.add_master(@u_mentioned)
    project.add_master(@u_committer)
    project.add_master(@u_not_mentioned)
    project.add_master(@u_lazy_participant)
    project.add_master(@u_custom_global)
  end

  def create_global_setting_for(user, level)
    setting = user.global_notification_setting
    setting.level = level
    setting.save

    user
  end

  def create_user_with_notification(level, username)
    user = create(:user, username: username)
    setting = user.notification_settings_for(project)
    setting.level = level
    setting.save

    user
  end

  # Create custom notifications
  # When resource is nil it means global notification
  def update_custom_notification(event, user, resource = nil)
    setting = user.notification_settings_for(resource)
    setting.events[event] = true
    setting.save
  end

  def add_users_with_subscription(project, issuable)
    @subscriber = create :user
    @unsubscriber = create :user
    @subscribed_participant = create_global_setting_for(create(:user, username: 'subscribed_participant'), :participating)
    @watcher_and_subscriber = create_global_setting_for(create(:user), :watch)

    project.add_master(@subscribed_participant)
    project.add_master(@subscriber)
    project.add_master(@unsubscriber)
    project.add_master(@watcher_and_subscriber)

    issuable.subscriptions.create(user: @subscriber, project: project, subscribed: true)
    issuable.subscriptions.create(user: @subscribed_participant, project: project, subscribed: true)
    issuable.subscriptions.create(user: @unsubscriber, project: project, subscribed: false)
    # Make the watcher a subscriber to detect dupes
    issuable.subscriptions.create(user: @watcher_and_subscriber, project: project, subscribed: true)
  end
end
