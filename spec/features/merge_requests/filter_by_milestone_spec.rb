require 'rails_helper'

feature 'Merge Request filtering by Milestone', feature: true do
  let(:project)   { create(:project, :public) }
  let!(:user)     { create(:user)}
  let(:milestone) { create(:milestone, project: project) }

  before do
    project.team << [user, :master]
    login_as(user)
  end

  scenario 'filters by no Milestone', js: true do
    create(:merge_request, :with_diffs, source_project: project)
    create(:merge_request, :simple, source_project: project, milestone: milestone)

    visit_merge_requests(project)
    filter_by_milestone(Milestone::None.title)

    expect(page).to have_issuable_counts(open: 1, closed: 0, all: 1)
    expect(page).to have_css('.merge-request', count: 1)
  end

  context 'filters by upcoming milestone', js: true do
    it 'does not show issues with no expiry' do
      create(:merge_request, :with_diffs, source_project: project)
      create(:merge_request, :simple, source_project: project, milestone: milestone)

      visit_merge_requests(project)
      filter_by_milestone(Milestone::Upcoming.title)

      expect(page).to have_css('.merge-request', count: 0)
    end

    it 'shows issues in future' do
      milestone = create(:milestone, project: project, due_date: Date.tomorrow)
      create(:merge_request, :with_diffs, source_project: project)
      create(:merge_request, :simple, source_project: project, milestone: milestone)

      visit_merge_requests(project)
      filter_by_milestone(Milestone::Upcoming.title)

      expect(page).to have_issuable_counts(open: 1, closed: 0, all: 1)
      expect(page).to have_css('.merge-request', count: 1)
    end

    it 'does not show issues in past' do
      milestone = create(:milestone, project: project, due_date: Date.yesterday)
      create(:merge_request, :with_diffs, source_project: project)
      create(:merge_request, :simple, source_project: project, milestone: milestone)

      visit_merge_requests(project)
      filter_by_milestone(Milestone::Upcoming.title)

      expect(page).to have_css('.merge-request', count: 0)
    end
  end

  scenario 'filters by a specific Milestone', js: true do
    create(:merge_request, :with_diffs, source_project: project, milestone: milestone)
    create(:merge_request, :simple, source_project: project)

    visit_merge_requests(project)
    filter_by_milestone(milestone.title)

    expect(page).to have_issuable_counts(open: 1, closed: 0, all: 1)
    expect(page).to have_css('.merge-request', count: 1)
  end

  context 'when milestone has single quotes in title' do
    background do
      milestone.update(name: "rock 'n' roll")
    end

    scenario 'filters by a specific Milestone', js: true do
      create(:merge_request, :with_diffs, source_project: project, milestone: milestone)
      create(:merge_request, :simple, source_project: project)

      visit_merge_requests(project)
      filter_by_milestone(milestone.title)

      expect(page).to have_issuable_counts(open: 1, closed: 0, all: 1)
      expect(page).to have_css('.merge-request', count: 1)
    end
  end

  def visit_merge_requests(project)
    visit namespace_project_merge_requests_path(project.namespace, project)
  end

  def filter_by_milestone(title)
    find(".js-milestone-select").click
    find(".milestone-filter a", text: title).click
  end
end
