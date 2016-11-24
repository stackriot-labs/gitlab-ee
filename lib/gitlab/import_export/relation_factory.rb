module Gitlab
  module ImportExport
    class RelationFactory
      OVERRIDES = { snippets: :project_snippets,
                    pipelines: 'Ci::Pipeline',
                    statuses: 'commit_status',
                    variables: 'Ci::Variable',
                    triggers: 'Ci::Trigger',
                    builds: 'Ci::Build',
                    hooks: 'ProjectHook',
                    merge_access_levels: 'ProtectedBranch::MergeAccessLevel',
                    push_access_levels: 'ProtectedBranch::PushAccessLevel',
                    labels: :project_labels,
                    priorities: :label_priorities,
                    label: :project_label }.freeze

      USER_REFERENCES = %w[author_id assignee_id updated_by_id user_id created_by_id].freeze

      PROJECT_REFERENCES = %w[project_id source_project_id gl_project_id target_project_id].freeze

      BUILD_MODELS = %w[Ci::Build commit_status].freeze

      IMPORTED_OBJECT_MAX_RETRIES = 5.freeze

      EXISTING_OBJECT_CHECK = %i[milestone milestones label labels project_label project_labels project_label group_label].freeze

      def self.create(*args)
        new(*args).create
      end

      def initialize(relation_sym:, relation_hash:, members_mapper:, user:, project_id:)
        @relation_name = OVERRIDES[relation_sym] || relation_sym
        @relation_hash = relation_hash.except('noteable_id').merge('project_id' => project_id)
        @members_mapper = members_mapper
        @user = user
        @imported_object_retries = 0
      end

      # Creates an object from an actual model with name "relation_sym" with params from
      # the relation_hash, updating references with new object IDs, mapping users using
      # the "members_mapper" object, also updating notes if required.
      def create
        setup_models

        generate_imported_object
      end

      private

      def setup_models
        if @relation_name == :notes
          set_note_author

          # attachment is deprecated and note uploads are handled by Markdown uploader
          @relation_hash['attachment'] = nil
        end

        update_user_references
        update_project_references

        handle_group_label if group_label?
        reset_ci_tokens if @relation_name == 'Ci::Trigger'
        @relation_hash['data'].deep_symbolize_keys! if @relation_name == :events && @relation_hash['data']
        set_st_diffs if @relation_name == :merge_request_diff
      end

      def update_user_references
        USER_REFERENCES.each do |reference|
          if @relation_hash[reference]
            @relation_hash[reference] = @members_mapper.map[@relation_hash[reference]]
          end
        end
      end

      # Sets the author for a note. If the user importing the project
      # has admin access, an actual mapping with new project members
      # will be used. Otherwise, a note stating the original author name
      # is left.
      def set_note_author
        old_author_id = @relation_hash['author_id']

        # Users with admin access can map users
        @relation_hash['author_id'] = admin_user? ? @members_mapper.map[old_author_id] : @members_mapper.default_user_id

        author = @relation_hash.delete('author')

        update_note_for_missing_author(author['name']) if missing_author?(old_author_id)
      end

      def missing_author?(old_author_id)
        !admin_user? || @members_mapper.missing_author_ids.include?(old_author_id)
      end

      def missing_author_note(updated_at, author_name)
        timestamp = updated_at.split('.').first
        "\n\n *By #{author_name} on #{timestamp} (imported from GitLab project)*"
      end

      def generate_imported_object
        if BUILD_MODELS.include?(@relation_name) # call #trace= method after assigning the other attributes
          trace = @relation_hash.delete('trace')
          imported_object do |object|
            object.trace = trace
            object.commit_id = nil
          end
        else
          imported_object
        end
      end

      def update_project_references
        project_id = @relation_hash.delete('project_id')

        # If source and target are the same, populate them with the new project ID.
        if @relation_hash['source_project_id']
          @relation_hash['source_project_id'] = same_source_and_target? ? project_id : -1
        end

        # project_id may not be part of the export, but we always need to populate it if required.
        @relation_hash['project_id'] = project_id
        @relation_hash['gl_project_id'] = project_id if @relation_hash['gl_project_id']
        @relation_hash['target_project_id'] = project_id if @relation_hash['target_project_id']
      end

      def same_source_and_target?
        @relation_hash['target_project_id'] && @relation_hash['target_project_id'] == @relation_hash['source_project_id']
      end

      def group_label?
        @relation_hash['type'] == 'GroupLabel'
      end

      def handle_group_label
        # If there's no group, move the label to a project label
        if @relation_hash['group_id']
          @relation_hash['project_id'] = nil
          @relation_name = :group_label
        else
          @relation_hash['type'] = 'ProjectLabel'
        end
      end

      def reset_ci_tokens
        return unless Gitlab::ImportExport.reset_tokens?

        # If we import/export a project to the same instance, tokens will have to be reset.
        @relation_hash['token'] = nil
      end

      def relation_class
        @relation_class ||= @relation_name.to_s.classify.constantize
      end

      def imported_object
        yield(existing_or_new_object) if block_given?
        existing_or_new_object.importing = true if existing_or_new_object.respond_to?(:importing)
        existing_or_new_object
      rescue ActiveRecord::RecordNotUnique
        # as the operation is not atomic, retry in the unlikely scenario an INSERT is
        # performed on the same object between the SELECT and the INSERT
        @imported_object_retries += 1
        retry if @imported_object_retries < IMPORTED_OBJECT_MAX_RETRIES
      end

      def update_note_for_missing_author(author_name)
        @relation_hash['note'] = '*Blank note*' if @relation_hash['note'].blank?
        @relation_hash['note'] += missing_author_note(@relation_hash['updated_at'], author_name)
      end

      def admin_user?
        @user.is_admin?
      end

      def parsed_relation_hash
        @parsed_relation_hash ||= Gitlab::ImportExport::AttributeCleaner.clean(relation_hash: @relation_hash,
                                                                               relation_class: relation_class)
      end

      def set_st_diffs
        @relation_hash['st_diffs'] = @relation_hash.delete('utf8_st_diffs')
      end

      def existing_or_new_object
        # Only find existing records to avoid mapping tables such as milestones
        # Otherwise always create the record, skipping the extra SELECT clause.
        @existing_or_new_object ||= begin
          if EXISTING_OBJECT_CHECK.include?(@relation_name)
            attribute_hash = attribute_hash_for(['events', 'priorities'])

            existing_object.assign_attributes(attribute_hash) if attribute_hash.any?

            existing_object
          else
            relation_class.new(parsed_relation_hash)
          end
        end
      end

      def attribute_hash_for(attributes)
        attributes.inject({}) do |hash, value|
          hash[value] = parsed_relation_hash.delete(value) if parsed_relation_hash[value]
          hash
        end
      end

      def existing_object
        @existing_object ||=
          begin
            finder_attributes = @relation_name == :group_label ? %w[title group_id] : %w[title project_id]
            finder_hash = parsed_relation_hash.slice(*finder_attributes)
            existing_object = relation_class.find_or_create_by(finder_hash)
            # Done in two steps, as MySQL behaves differently than PostgreSQL using
            # the +find_or_create_by+ method and does not return the ID the second time.
            existing_object.update!(parsed_relation_hash)
            existing_object
          end
      end
    end
  end
end
