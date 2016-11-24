Please view this file on the master branch, on stable branches it's out of date.

## 8.14.0 (2016-11-22)

- Added Backfill service for Geo. !861
- Fix for autosuggested approvers(https://gitlab.com/gitlab-org/gitlab-ee/issues/1273).
- Gracefully recover from previously failed rebase.
- Disable retries for remote mirror update worker. !848
- Fix Approvals API documentation.
- Add ability to set approvals_before_merge for project through the API.
- gitlab:check rake task checks ES version according to requirements
- Convert ASCII-8BIT LDAP DNs to UTF-8 to avoid unnecessary user deletions
- [Fix] Only owner can see "Projects" button in group edit menu

## 8.13.6 (2016-11-17)

- Disable retries for remote mirror update worker. !848
- Fixed cache clearing on secondary Geo nodes. !869
- Geo: fix a problem that prevented git cloning from secondary node. !873

## 8.13.5 (2016-11-08)

- No changes

## 8.13.4 (2016-11-07)

- Weight dropdown in issue filter form does not stay selected. !826

## 8.13.3 (2016-11-02)

- No changes

## 8.13.2 (2016-10-31)

- Don't pass a current user to Member#add_user in LDAP group sync. !830

## 8.13.1 (2016-10-25)

- Hide multiple board actions if user doesnt have permissions. !816
- Fix Elasticsearch::Transport::Transport::Errors::BadRequest when ES is enabled. !818

## 8.13.0 (2016-10-22)

- Cache the last usage data to avoid unicorn timeouts
- Add user activity table and service to query for active users
- Fix 500 error updating mirror URLs for projects
- Restrict protected branch access to specific groups !645
- Fix validations related to mirroring settings form. !773
- Add multiple issue boards. !782
- Fix Git access panel for Wikis when Kerberos authentication is enabled (Borja Aparicio)
- Decrease maximum time that GitLab waits for a mirror to finish !791 (Borja Aparicio)
- User groups (that can be assigned as approvers)
- Fix a search for non-default branches when ES is enabled
- Re-organized the Sidekiq queues for EE specific workers

## 8.12.9 (2016-11-07)

- No changes

## 8.12.8 (2016-11-02)

- No changes

## 8.12.7

  - No EE-specific changes

## 8.12.6

  - No EE-specific changes

## 8.12.5

  - No EE-specific changes

## 8.12.4

  - [ES] Indexer works with smaller batches of repositories to not exceed NOFILE limit. !774

## 8.12.3

  - Fix prevent_secrets checkbox on admin view

## 8.12.2

  - Fix bug when protecting a branch due to missing url paramenter in request !760
  - Ignore unknown project ID in RepositoryUpdateMirrorWorker

## 8.12.1

  - Prevent secrets to be pushed to the repository
  - Prevent secrets to be pushed to the repository

## 8.12.0 (2016-09-22)

  - Include more data in EE usage ping
  - Reduce UPDATE queries when moving between import states on projects
  - [ES] Instrument Elasticsearch::Git::Repository
  - Request only the LDAP attributes we need
  - Add 'Sync now' to group members page !704
  - Add repository size limits and enforce them !740
  - [ES] Instrument other Gitlab::Elastic classes
  - [ES] Fix: Elasticsearch does not find partial matches in project names
  - Faster Active Directory group membership resolution !719
  - [ES] Global code search
  - [ES] Improve logging
  - Fix projects with remote mirrors asynchronously destruction

## 8.11.11 (2016-11-07)

- No changes

## 8.11.10 (2016-11-02)

- No changes

## 8.11.9

  - No EE-specific changes

## 8.11.8

  - No EE-specific changes

## 8.11.7

  - Refactor Protected Branches dropdown. !687
  - Fix mirrored projects allowing empty import urls. !700

## 8.11.6

  - Exclude blocked users from potential MR approvers.

## 8.11.5

  - API: Restore backward-compatibility for POST /projects/:id/members when membership is locked

## 8.11.4

  - No EE-specific changes

## 8.11.3

  - [ES] Add logging to indexer
  - Fix missing EE-specific service parameters for Jenkins CI
  - Set the correct `GL_PROTOCOL` when rebasing !691
  - [ES] Elasticsearch workers checks ES settings before running

## 8.11.2

  - Additional documentation on protected branches for EE
  - Change slash commands docs location

## 8.11.1

  - Pulled due to packaging error.

## 8.11.0 (2016-08-22)

  - Allow projects to be moved between repository storages
  - Add rake task to remove old repository copies from repositories moved to another storage
  - Performance improvement of push rules
  - Temporary fix for #825 - LDAP sync converts access requests to members. !655
  - Optimize commit and diff changes access check to reduce git operations
  - Allow syncing a group against all providers at once
  - Change LdapGroupSyncWorker to use new LDAP group sync classes
  - Allow LDAP `sync_ssh_keys` setting to be set to `true`
  - Removed unused GitLab GEO database index
  - Restrict protected branch access to specific users !581
  - Enable monitoring for ES classes
  - [Elastic] Improve code search
  - [Elastic] Significant improvement of global search performance
  - [Fix] Push rules check existing commits in some cases
  - [ES] Limit amount of retries for sidekiq jobs
  - Fix Projects::UpdateMirrorService to allow tags pointing to blob objects

## 8.10.12

  - No EE-specific changes

## 8.10.11

  - No EE-specific changes

## 8.10.10

  - No EE-specific changes

## 8.10.9

  - Exclude blocked users from potential MR approvers.

## 8.10.8

  - No EE-specific changes

## 8.10.7

  - No EE-specific changes

## 8.10.6

  - Fix race condition with UpdateMirrorWorker Lease. !641

## 8.10.5

  - Used cached value of project count in `Elastic::RepositoriesSearch` to reduce DB load. !637

## 8.10.4

  - Fix available users in userselect dropdown when there is more than one userselect on the page. !604 (Rik de Groot)
  - Fix updating skipped approvers in search list on removal. !604 (Rik de Groot)

## 8.10.3

  - Fix regression in Git Annex permission check. !599
  - [Elastic] Fix commit search for some URLs. !605
  - [Elastic][Fix] Commit search breaks for some URLs on gitlab-ce project

## 8.10.2

  - Fix pagination on search result page when ES search is enabled. !592
  - Decouple an ES index update from `RepositoryUpdateMirrorWorker`. !593
  - Fix broken `user_allowed?` check in Git Annex push. !597

## 8.10.1

  - No EE-specific changes

## 8.10.0 (2016-07-22)

  - Add EE license usage ping !557
  - Rename Git Hooks to Push Rules
  - Fix EE keys fingerprint add index migration if came from CE
  - Add todos for MR approvers !547
  - Replace LDAP group sync exclusive lease with state machine
  - Prevent the author of an MR from being on the approvers list
  - Isolate EE LDAP library code in EE module (Part 1) !511
  - Make Elasticsearch indexer run as an async task
  - Fix of removing wiki data from index when project is deleted
  - Ticket-based Kerberos authentication (SPNEGO)
  - [Elastic] Suppress ActiveRecord::RecordNotFound error in ElasticIndexWorker

## 8.9.10

  - No EE-specific changes

## 8.9.9

  - No EE-specific changes

## 8.9.8

  - No EE-specific changes

## 8.9.7

  - No EE-specific changes

## 8.9.6

  - Avoid adding index for key fingerprint if it already exists. !539

## 8.9.5

  - Fix of quoted text in lock tooltip. !518

## 8.9.4

  - Improve how File Lock feature works with nested items. !497

## 8.9.3

  - Fix encrypted data backwards compatibility after upgrading attr_encrypted gem. !502
  - Fix creating MRs on forks of deleted projects. !503
  - Roll back Grack::Auth to fix Git HTTP SPNEGO. !504

## 8.9.2

  - [Elastic] Fix visibility of snippets when searching.

## 8.9.1

  - Improve Geo documentation. !431
  - Fix remote mirror stuck on started issue. !491
  - Fix MR creation from forks where target project has approvals enabled. !496
  - Fix MR edit where target project has approvals enabled. !496
  - Fix vertical alignment of git-hooks page. !499

## 8.9.0 (2016-06-22)

  - Fix JenkinsService test button
  - Fix nil user handling in UpdateMirrorService
  - Allow overriding the number of approvers for a merge request
  - Allow LDAP to mark users as external based on their group membership. !432
  - Instrument instance methods of Gitlab::InsecureKeyFingerprint class
  - Add API endpoint for Merge Request Approvals !449
  - Send notification email when merge request is approved
  - Distribute RepositoryUpdateMirror jobs in time and add exclusive lease on them by project_id
  - [Elastic] Move ES settings to application settings
  - Always allow merging a merge request whenever fast-forward is possible. !454
  - Disable mirror flag for projects without import_url
  - UpdateMirror service return an error status when no mirror
  - Don't reset approvals when rebasing an MR from the UI
  - Show flash notice when Git Hooks are updated successfully
  - Remove explicit Gitlab::Metrics.action assignments, are already automatic.
  - [Elastic] Project members with guest role can't access confidential issues
  - Ability to lock file or folder in the repository
  - Fix: Git hooks don't fire when committing from the UI

## 8.8.9

  - No EE-specific changes

## 8.8.8

  - No EE-specific changes

## 8.8.7

  - No EE-specific changes

## 8.8.6

  - [Elastic] Fix visibility of snippets when searching.

## 8.8.5

  - Make sure OAuth routes that we generate for Geo matches with the ones in Rails routes !444

## 8.8.4

  - Remove license overusage message

## 8.8.3

  - Add standard web hook headers to Jenkins CI post. !374
  - Gracefully handle malformed DNs in LDAP group sync. !392
  - Reduce load on DB for license upgrade check. !421
  - Make it clear the license overusage message is visible only to admins. !423
  - Fix Git hook validations for fast-forward merges. !427
  - [Elastic] In search results, only show notes on confidential issues that the user has access to.

## 8.8.2

  - Fix repository mirror updates for new imports stuck in started
  - [Elastic] Search through the filenames. !409
  - Fix repository mirror updates for new imports stuck in "started" state. !416

## 8.8.1

  - No EE-specific changes

## 8.8.0 (2016-05-22)

  - [Elastic] Database indexer prints its status
  - [Elastic][Fix] Database indexer skips projects with invalid HEAD reference
  - Fix skipping pages when restoring backups
  - Add EE license via API !400
  - [Elastic] More efficient snippets search
  - [Elastic] Add rake task for removing all indexes
  - [Elastic] Add rake task for clearing indexing status
  - [Elastic] Improve code search
  - [Elastic] Fix encoding issues during indexing
  - Warn admin if current active count exceeds license
  - [Elastic] Search through the filenames
  - Set KRB5 as default clone protocol when Kerberos is enabled and user is logged in (Borja Aparicio)
  - Add support for Admin Groups to SAML
  - Reduce emails-on-push HTML size by using a simple monospace font
  - API requests to /internal/authorized_keys are now tagged properly
  - Geo: Single Sign Out support !380

## 8.7.9

  - No EE-specific changes

## 8.7.8

  - [Elastic] Fix visibility of snippets when searching.

## 8.7.7

  - No EE-specific changes

## 8.7.6

  - Bump GitLab Pages to 0.2.4 to fix Content-Type for predefined 404

## 8.7.5

  - No EE-specific changes

## 8.7.4

  - Delete ProjectImportData record only if Project is not a mirror !370
  - Fixed typo in GitLab GEO license check alert !379
  - Fix LDAP access level spillover bug !499

## 8.7.3

  - No EE-specific changes

## 8.7.2

  - Fix MR notifications for slack and hipchat when approvals are fullfiled. !325
  - GitLab Geo: Merge requests on Secondary should not check mergeable status

## 8.7.1

  - No EE-specific changes

## 8.7.0 (2016-04-22)

  - Update GitLab Pages to 0.2.1: support user-defined 404 pages
  - Refactor group sync to pull access level logic to its own class. !306
  - [Elastic] Stabilize database indexer if database is inconsistent
  - Add ability to sync to remote mirrors. !249
  - GitLab Geo: Many replication improvements and fixes !354

## 8.6.9

  - No EE-specific changes

## 8.6.8

  - No EE-specific changes

## 8.6.7

  - No EE-specific changes

## 8.6.6

  - Concat AD group recursive member results with regular member results. !333
  - Fix LDAP group sync regression for groups with member value `uid=<username>`. !335
  - Don't attempt to include too large diffs in e-mail-on-push messages (Stan Hu). !338

## 8.6.5

  - No EE-specific changes

## 8.6.4

  - No EE-specific changes

## 8.6.3

  - Fix other cases where git hooks would fail due to old commits. !310
  - Exit ElasticIndexerWorker's job happily if record cannot be found. !311
  - Fix "Reload with full diff" button not working (Stan Hu). !313

## 8.6.2

  - Fix old commits triggering git hooks on new branches branched off another branch. !281
  - Fix issue with deleted user in audit event (Stan Hu). !284
  - Mark pending todos as done when approving a merge request. !292
  - GitLab Geo: Display Attachments from Primary node. !302

## 8.6.1

  - Only rename the `light_logo` column in the `appearances` table if its not there yet. !290
  - Fix diffs in text part of email-on-push messages (Stan Hu). !293
  - Fix an issue with methods not accessible in some controllers. !295
  - Ensure Projects::ApproversController inherits from Projects::ApplicationController. !296

## 8.6.0 (2016-03-22)

  - Handle duplicate appearances table creation issue with upgrade from CE to EE
  - Add confidential issues
  - Improve weight filter for issues
  - Update settings and documentation for per-install LDAP sync time
  - Fire merge request webhooks when a merge request is approved
  - Add full diff highlighting to Email on push
  - Clear "stuck" mirror updates before periodically updating all mirrors
  - LDAP: Don't render Linked LDAP groups forms when LDAP is disabled
  - [Elastic] Add elastic checker to gitlab:check
  - [Elastic] Added UPDATE_INDEX option to rake task
  - [Elastic] Removing repository and wiki index after removing project
  - [Elastic] Update index on push to wiki
  - [Elastic] Use subprocesses for ElasticSearch index jobs
  - [Elastic] More accurate as_indexed_json (More stable database indexer)
  - [Elastic] Fix: Don't index newly created system messages and awards
  - [Elastic] Fixed exception on branch removing
  - [Elastic] Fix bin/elastic_repo_indexer to follow config
  - GitLab Geo: OAuth authentication
  - GitLab Geo: Wiki synchronization
  - GitLab Geo: ReadOnly Middleware improvements
  - GitLab Geo: SSH Keys synchronization
  - Allow SSL verification to be configurable when importing GitHub projects
  - Disable git-hooks for git annex commits

## 8.5.13

  - No EE-specific changes

## 8.5.12

  - No EE-specific changes

## 8.5.11

  - Fix vulnerability that made it possible to enumerate private projects belonging to group

## 8.5.10

  - No EE-specific changes

## 8.5.9

  - No EE-specific changes

## 8.5.8

  - GitLab Geo: Documentation

## 8.5.7

  - No EE-specific changes

## 8.5.6

  - No EE-specific changes

## 8.5.5

  - GitLab Geo: Repository synchronization between primary and secondary nodes
  - Add documentation for GitLab Pages
  - Fix importing projects from GitHub Enterprise Edition
  - Fix syntax error in init file
  - Only show group member roles if explicitly requested
  - GitLab Geo: Improve GeoNodes Admin screen
  - GitLab Geo: Avoid locking yourself out when adding a GeoNode

## 8.5.4

  - [Elastic][Security] Notes exposure

## 8.5.3

  - Prevent LDAP from downgrading a group's last owner
  - Update gitlab-elastic-search gem to 0.0.11

## 8.5.2

  - Update LDAP groups asynchronously
  - Fix an issue when weight text was displayed in Issuable collapsed sidebar
## 8.5.2

  - Fix importing projects from GitHub Enterprise Edition.

## 8.5.1

  - Fix adding pages domain to projects in groups

## 8.5.0 (2016-02-22)

  - Fix Elasticsearch blob results linking to the wrong reference ID (Stan Hu)
  - Show warning when mirror repository default branch could not be updated because it has diverged from upstream.
  - More reliable wiki indexer
  - GitLab Pages gets support for custom domain and custom certificate
  - Fix of Elastic indexer. It should not trigger record validation for projects
  - Fix of Elastic indexer. Stabilze indexer when serialized data is corrupted
  - [Elastic] Don't index unnecessary data into elastic

## 8.4.11

  - No EE-specific changes

## 8.4.10

  - No EE-specific changes

## 8.4.9

  - Fix vulnerability that made it possible to enumerate private projects belonging to group

## 8.4.8

  - No EE-specific changes

## 8.4.7

  - No EE-specific changes

## 8.4.6

  - No EE-specific changes

## 8.4.5

  - Update LDAP groups asynchronously

## 8.4.4

  - Re-introduce "Send email to users" link in Admin area
  - Fix category values for Jenkins and JenkinsDeprecated services
  - Fix Elasticsearch indexing for newly added snippets
  - Make Elasticsearch indexer more stable
  - Update gitlab-elasticsearch-git to 0.0.10 which contain a few important fixes

## 8.4.3

  - Elasticsearch: fix partial blob indexing on push
  - Elasticsearch: added advanced indexer for repositories
  - Fix Mirror User dropdown

## 8.4.2

  - Elasticsearch indexer performance improvements
  - Don't redirect away from Mirror Repository settings when repo is empty
  - Fix updating of branches in mirrored repository
  - Fix a 500 error preventing LDAP users with 2FA enabled from logging in
  - Rake task gitlab:elastic:index_repositories handles errors and shows progress
  - Partial indexing of repo on push (indexing changes only)

## 8.4.1

  - No EE-specific changes

## 8.4.0 (2016-01-22)

  - Add ability to create a note for user by admin
  - Fix "Commit was rejected by git hook", when max_file_size was set null in project's Git hooks
  - Fix "Approvals are not reset after a new push is made if the request is coming from a fork"
  - Fix "User is not automatically removed from suggested approvers list if user is deleted"
  - Add option to enforce a semi-linear history by only allowing merge requests to be merged that have been rebased
  - Add option to trigger builds when branches or tags are updated from a mirrored upstream repository
  - Ability to use Elasticsearch as a search engine

## 8.3.10

  - No EE-specific changes

## 8.3.9

  - No EE-specific changes

## 8.3.8

  - Fix vulnerability that made it possible to enumerate private projects belonging to group

## 8.3.7

  - No EE-specific changes

## 8.3.6

  - No EE-specific changes

## 8.3.5

  - No EE-specific changes

## 8.3.4

  - No EE-specific changes

## 8.3.3

  - Fix undefined method call in Jenkins integration service

## 8.3.2

  - No EE-specific changes

## 8.3.1

  - Rename "Group Statistics" to "Contribution Analytics"

## 8.3.0 (2015-12-22)

  - License information can now be retrieved via the API
  - Show Kerberos clone url when Kerberos enabled and url different than HTTP url (Borja Aparicio)
  - Fix bug with negative approvals required
  - Add group contribution analytics page
  - Add GitLab Pages
  - Add group contribution statistics page
  - Automatically import Kerberos identities from Active Directory when Kerberos is enabled (Alex Lossent)
  - Canonicalization of Kerberos identities to always include realm (Alex Lossent)

## 8.2.6

  - No EE-specific changes

## 8.2.5

  - No EE-specific changes

## 8.2.4

  - No EE-specific changes

## 8.2.3

  - No EE-specific changes

## 8.2.2

  - Fix 404 in redirection after removing a project (Stan Hu)
  - Ensure cached application settings are refreshed at startup (Stan Hu)
  - Fix Error 500 when viewing user's personal projects from admin page (Stan Hu)
  - Fix: Raw private snippets access workflow
  - Prevent "413 Request entity too large" errors when pushing large files with LFS
  - Ensure GitLab fires custom update hooks after commit via UI

## 8.2.1

  - Forcefully update builds that didn't want to update with state machine
  - Fix: saving GitLabCiService as Admin Template

## 8.2.0 (2015-11-22)

  - Invalidate stored jira password if the endpoint URL is changed
  - Fix: Page is not reloaded periodically to check if rebase is finished
  - When someone as marked as a required approver for a merge request, an email should be sent
  - Allow configuring the Jira API path (Alex Lossent)
  - Fix "Rebase onto master"
  - Ensure a comment is properly recorded in JIRA when a merge request is accepted
  - Allow groups to appear in the `Share with group` share if the group owner allows it
  - Add option to mirror an upstream repository.

## 8.1.4

  - Fix bug in JIRA integration which prevented merge requests from being accepted when using issue closing pattern

## 8.1.3

  - Fix "Rebase onto master"

## 8.1.2

  - Prevent a 500 error related to the JIRA external issue tracker service

## 8.1.1

  - Removed, see 8.1.2

## 8.1.0 (2015-10-22)

  - Add documentation for "Share project with group" API call
  - Added an issues template (Hannes Rosenögger)
  - Add documentation for "Share project with group" API call
  - Ability to disable 'Share with Group' feature (via UI and API)

## 8.0.6

  - No EE-specific changes

## 8.0.5

  - "Multi-project" and "Treat unstable builds as passing" parameters for
    the Jenkins CI service are now correctly persisted.
  - Correct the build URL when "Multi-project" is enabled for the Jenkins CI
    service.

## 8.0.4

  - Fix multi-project setup for Jenkins

## 8.0.3

  - No EE-specific changes

## 8.0.2

  - No EE-specific changes

## 8.0.1

  - Correct gem dependency versions
  - Re-add the "Help Text" feature that was inadvertently removed

## 8.0.0 (2015-09-22)

  - Fix navigation issue when viewing Group Settings pages
  - Guests and Reporters can approve merge request as well
  - Add fast-forward merge option in project settings
  - Separate rebase & fast-forward merge features

## 7.14.3

  - No changes

## 7.14.2

  - Fix the rebase before merge feature

## 7.14.1

  - Fix sign in form when just Kerberos is enabled

## 7.14.0 (2015-08-22)

  - Disable adding, updating and removing members from a group that is synced with LDAP
  - Don't send "Added to group" notifications when group is LDAP synched
  - Fix importing projects from GitHub Enterprise Edition.
  - Automatic approver suggestions (based on an authority of the code)
  - Add support for Jenkins unstable status
  - Automatic approver suggestions (based on an authority of the code)
  - Support Kerberos ticket-based authentication for Git HTTP access

## 7.13.3

  - Merge community edition changes for version 7.13.3
  - Improved validation for an approver
  - Don't resend admin email to everyone if one delivery fails
  - Added migration for removing of invalid approvers

## 7.13.2

  - Fix group web hook
  - Don't resend admin email to everyone if one delivery fails

## 7.13.1

  - Merge community edition changes for version 7.13.1
  - Fix: "Rebase before merge" doesn't work when source branch is in the same project

## 7.13.0 (2015-07-22)

  - Fix git hook validation on initial push to master branch.
  - Reset approvals on push
  - Fix 500 error when the source project of an MR is deleted
  - Ability to define merge request approvers

## 7.12.2

  - Fixed the alignment of project settings icons

## 7.12.1

  - No changes specific to EE

## 7.12.0 (2015-06-22)

  - Fix error when viewing merge request with a commit that includes "Closes #<issue id>".
  - Enhance LDAP group synchronization to check also for member attributes that only contain "uid=<username>"
  - Enhance LDAP group synchronization to check also for submember attributes
  - Prevent LDAP group sync from removing a group's last owner
  - Add Git hook to validate maximum file size.
  - Project setting: approve merge request by N users before accept
  - Support automatic branch jobs created by Jenkins in CI Status
  - Add API support for adding and removing LDAP group links

## 7.11.4

  - no changes specific to EE

## 7.11.3

  - Fixed an issue with git annex

## 7.11.2

  - Fixed license upload and verification mechanism

## 7.11.0 (2015-05-22)

  - Skip git hooks commit validation when pushing new tag.
  - Add Two-factor authentication (2FA) for LDAP logins

## 7.10.1

  - Check if comment exists in Jira before sending a reference

## 7.10.0 (2015-04-22)

  - Improve UI for next pages: Group LDAP sync, Project git hooks, Project share with groups, Admin -> Appearance settigns
  - Default git hooks for new projects
  - Fix LDAP group links page by using new group members route.
  - Skip email confirmation when updated via LDAP.

## 7.9.0 (2015-03-22)

  - Strip prefixes and suffixes from synced SSH keys:
    `SSHKey:ssh-rsa keykeykey` and `ssh-rsa keykeykey (SSH key)` will now work
  - Check if LDAP admin group exists before querying for user membership
  - Use one custom header logo for all GitLab themes in appearance settings
  - Escape wildcards when searching LDAP by group name.
  - Group level Web Hooks
  - Don't allow project to be shared with the group it is already in.

## 7.8.0 (2015-02-22)

  - Improved Jira issue closing integration
  - Improved message logging for Jira integration
  - Added option of referencing JIRA issues from GitLab
  - Update Sidetiq to 0.6.3
  - Added Github Enterprise importer
  - When project has MR rebase enabled, MR will have rebase checkbox selected by default
  - Minor UI fixes for sidebar navigation
  - Manage large binaries with git annex

## 7.7.0 (2015-01-22)

  - Added custom header logo support (Drew Blessing)
  - Fixed preview appearance bug
  - Improve performance for selectboxes: project share page, admin email users page

## 7.6.2

  - Fix failing migrations for MySQL, LDAP

## 7.6.1

  - No changes

## 7.6.0 (2014-12-22)

  - Added Audit events related to membership changes for groups and projects
  - Added option to attempt a rebase before merging merge request
  - Dont show LDAP groups settings if LDAP disabled
  - Added member lock for groups to disallow membership additions on project level
  - Rebase on merge request. Introduced merge request option to rebase before merging
  - Better message for failed pushes because of git hooks
  - Kerberos support for web interface and git HTTP

## 7.5.3

  - Only set up Sidetiq from a Sidekiq server process (fixes Redis::InheritedError)

## 7.5.0 (2014-11-22)

  - Added an ability to check each author commit's email by regex
  - Added an ability to restrict commit authors to existing Gitlab users
  - Add an option for automatic daily LDAP user sync
  - Added git hook for preventing tag removal to API
  - Added git hook for setting commit message regex to API
  - Added an ability to block commits with certain filenames by regex expression
  - Improved a jenkins parser

## 7.4.4

  - Fix broken ldap migration

## 7.4.0 (2014-10-22)

  - Support for multiple LDAP servers
  - Skip AD specific LDAP checks
  - Do not show ldap users in dropdowns for groups with enabled ldap-sync
  - Update the JIRA integration documentation
  - Reset the homepage to show the GitLab logo by deleting the custom logo.

## 7.3.0 (2014-09-22)

  - Add an option to change the LDAP sync time from default 1 hour
  - User will receive an email when unsubscribed from admin notifications
  - Show group sharing members on /my/project/team
  - Improve explanation of the LDAP permission reset
  - Fix some navigation issues
  - Added support for multiple LDAP groups per Gitlab group

## 7.2.0 (2014-08-22)

  - Improve Redmine integration
  - Better logging for the JIRA issue closing service
  - Administrators can now send email to all users through the admin interface
  - JIRA issue transition ID is now customizable
  - LDAP group settings are now visible in admin group show page and group members page

## 7.1.0 (2014-07-22)

  - Synchronize LDAP-enabled GitLab administrators with an LDAP group (Marvin Frick, sponsored by SinnerSchrader)
  - Synchronize SSH keys with LDAP (Oleg Girko (Jolla) and Marvin Frick (SinnerSchrader))
  - Support Jenkins jobs with multiple modules (Marvin Frick, sponsored by SinnerSchrader)

## 7.0.0 (2014-06-22)

  - Fix: empty brand images are displayed as empty image_tag on login page (Marvin Frick, sponsored by SinnerSchrader)

## 6.9.4

  - Fix bug in JIRA Issue closing triggered by commit messages
  - Fix JIRA issue reference bug

## 6.9.3

  - Fix check CI status only when CI service is enabled(Daniel Aquino)

## 6.9.2

  - Merge community edition changes for version 6.9.2

## 6.9.1

  - Merge community edition changes for version 6.9.1

## 6.9.0 (2014-05-22)

  - Add support for closing Jira tickets with commits and MR
  - Template for Merge Request description can be added in project settings
  - Jenkins CI service
  - Fix LDAP email upper case bug

## 6.8.0 (2014-04-22)

  - Customise sign-in page with custom text and logo

## 6.7.1

  - Handle LDAP errors in Adapter#dn_matches_filter?

## 6.7.0 (2014-03-22)

  - Improve LDAP sign-in speed by reusing connections
  - Add support for Active Directory nested LDAP groups
  - Git hooks: Commit message regex
  - Git hooks: Deny git tag removal
  - Fix group edit in admin area

## 6.6.0 (2014-02-22)

  - Permission reset button for LDAP groups
  - Better performance with large numbers of users with access to one project

## 6.5.0 (2014-01-22)

  - Add reset permissions button to Group#members page

## 6.4.0 (2013-12-22)

  - Respect existing group permissions during sync with LDAP group (d3844662ec7ce816b0a85c8b40f66ee6c5ae90a1)

## 6.3.0 (2013-11-22)

  - When looking up a user by DN, use single scope (bc8a875df1609728f1c7674abef46c01168a0d20)
  - Try sAMAccountName if omniauth nickname is nil (9b7174c333fa07c44cc53b80459a115ef1856e38)

## 6.2.0 (2013-10-22)

  - API: expose ldap_cn and ldap_access group attributes
  - Use omniauth-ldap nickname attribute as GitLab username
  - Improve group sharing UI for installation with many groups
  - Fix empty LDAP group raises exception
  - Respect LDAP user filter for git access
