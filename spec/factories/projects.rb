FactoryGirl.define do
  # Project without repository
  #
  # Project does not have bare repository.
  # Use this factory if you don't need repository in tests
  factory :empty_project, class: 'Project' do
    sequence(:name) { |n| "project#{n}" }
    path { name.downcase.gsub(/\s/, '_') }
    namespace
    creator

    # Behaves differently to nil due to cache_has_external_issue_tracker
    has_external_issue_tracker false

    trait :public do
      visibility_level Gitlab::VisibilityLevel::PUBLIC
    end

    trait :internal do
      visibility_level Gitlab::VisibilityLevel::INTERNAL
    end

    trait :private do
      visibility_level Gitlab::VisibilityLevel::PRIVATE
    end

    trait :import_started do
      import_url FFaker::Internet.uri('http')
      import_status :started
    end

    trait :import_finished do
      import_started
      import_status :finished
    end

    trait :mirror do
      import_started

      mirror true
      mirror_user_id { creator_id }
    end

    trait :access_requestable do
      request_access_enabled true
    end

    trait :empty_repo do
      after(:create) do |project|
        project.create_repository
      end
    end

    trait :read_only_repository do
      repository_read_only true
    end

    trait :broken_repo do
      after(:create) do |project|
        project.create_repository

        FileUtils.rm_r(File.join(project.repository_storage_path, "#{project.path_with_namespace}.git", 'refs'))
      end
    end

    # Nest Project Feature attributes
    transient do
      wiki_access_level ProjectFeature::ENABLED
      builds_access_level ProjectFeature::ENABLED
      snippets_access_level ProjectFeature::ENABLED
      issues_access_level ProjectFeature::ENABLED
      merge_requests_access_level ProjectFeature::ENABLED
      repository_access_level ProjectFeature::ENABLED
    end

    after(:create) do |project, evaluator|
      # Builds and MRs can't have higher visibility level than repository access level.
      builds_access_level = [evaluator.builds_access_level, evaluator.repository_access_level].min
      merge_requests_access_level = [evaluator.merge_requests_access_level, evaluator.repository_access_level].min

      project.project_feature.
        update_attributes!(
          wiki_access_level: evaluator.wiki_access_level,
          builds_access_level: builds_access_level,
          snippets_access_level: evaluator.snippets_access_level,
          issues_access_level: evaluator.issues_access_level,
          merge_requests_access_level: merge_requests_access_level,
          repository_access_level: evaluator.repository_access_level
        )
    end
  end

  # Project with empty repository
  #
  # This is a case when you just created a project
  # but not pushed any code there yet
  factory :project_empty_repo, parent: :empty_project do
    empty_repo
  end

  # Project with broken repository
  #
  # Project with an invalid repository state
  factory :project_broken_repo, parent: :empty_project do
    broken_repo
  end

  # Project with test repository
  #
  # Test repository source can be found at
  # https://gitlab.com/gitlab-org/gitlab-test
  factory :project, parent: :empty_project do
    path { 'gitlabhq' }

    after :create do |project|
      TestEnv.copy_repo(project)
    end
  end

  factory :forked_project_with_submodules, parent: :empty_project do
    path { 'forked-gitlabhq' }

    after :create do |project|
      TestEnv.copy_forked_repo_with_submodules(project)
    end
  end

  factory :redmine_project, parent: :project do
    has_external_issue_tracker true

    after :create do |project|
      project.create_redmine_service(
        active: true,
        properties: {
          'project_url' => 'http://redmine/projects/project_name_in_redmine',
          'issues_url' => "http://redmine/#{project.id}/project_name_in_redmine/:id",
          'new_issue_url' => 'http://redmine/projects/project_name_in_redmine/issues/new'
        }
      )
    end
  end

  factory :jira_project, parent: :project do
    has_external_issue_tracker true

    after :create do |project|
      project.create_jira_service(
        active: true,
        properties: {
          title: 'JIRA tracker',
          url: 'http://jira.example.net',
          project_key: 'JIRA'
        }
      )
    end
  end
end
