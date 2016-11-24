require 'spec_helper'

describe 'Dashboard > User filters todos', feature: true, js: true do
  include WaitForAjax

  let(:user_1)    { create(:user, username: 'user_1', name: 'user_1') }
  let(:user_2)    { create(:user, username: 'user_2', name: 'user_2') }

  let(:project_1) { create(:empty_project, name: 'project_1') }
  let(:project_2) { create(:empty_project, name: 'project_2') }

  let(:issue) { create(:issue, title: 'issue', project: project_1) }

  let!(:merge_request) { create(:merge_request, source_project: project_2, title: 'merge_request') }

  before do
    create(:todo, user: user_1, author: user_2, project: project_1, target: issue, action: 1)
    create(:todo, user: user_1, author: user_1, project: project_2, target: merge_request, action: 2)

    project_1.team << [user_1, :developer]
    project_2.team << [user_1, :developer]
    login_as(user_1)
    visit dashboard_todos_path
  end

  it 'filters by project' do
    click_button 'Project'
    within '.dropdown-menu-project' do
      fill_in 'Search projects', with: project_1.name_with_namespace
      click_link project_1.name_with_namespace
    end

    wait_for_ajax

    expect(page).to     have_content project_1.name_with_namespace
    expect(page).not_to have_content project_2.name_with_namespace
  end

  context "Author filter" do
    it 'filters by author' do
      click_button 'Author'

      within '.dropdown-menu-author' do
        fill_in 'Search authors', with: user_1.name
        click_link user_1.name
      end

      wait_for_ajax

      expect(find('.todos-list')).to     have_content user_1.name
      expect(find('.todos-list')).not_to have_content user_2.name
    end

    it "shows only authors of existing todos" do
      click_button 'Author'

      within '.dropdown-menu-author' do
        # It should contain two users + "Any Author"
        expect(page).to have_selector('.dropdown-menu-user-link', count: 3)
        expect(page).to have_content(user_1.name)
        expect(page).to have_content(user_2.name)
      end
    end

    it "shows only authors of existing done todos" do
      user_3 = create :user
      user_4 = create :user
      create(:todo, user: user_1, author: user_3, project: project_1, target: issue, action: 1, state: :done)
      create(:todo, user: user_1, author: user_4, project: project_2, target: merge_request, action: 2, state: :done)

      project_1.team << [user_3, :developer]
      project_2.team << [user_4, :developer]

      visit dashboard_todos_path(state: 'done')

      click_button 'Author'

      within '.dropdown-menu-author' do
        # It should contain two users + "Any Author"
        expect(page).to have_selector('.dropdown-menu-user-link', count: 3)
        expect(page).to have_content(user_3.name)
        expect(page).to have_content(user_4.name)
        expect(page).not_to have_content(user_1.name)
        expect(page).not_to have_content(user_2.name)
      end
    end
  end

  it 'filters by type' do
    click_button 'Type'
    within '.dropdown-menu-type' do
      click_link 'Issue'
    end

    wait_for_ajax

    expect(find('.todos-list')).to     have_content issue.to_reference
    expect(find('.todos-list')).not_to have_content merge_request.to_reference
  end

  it 'filters by action' do
    click_button 'Action'
    within '.dropdown-menu-action' do
      click_link 'Assigned'
    end

    wait_for_ajax

    expect(find('.todos-list')).to     have_content ' assigned you '
    expect(find('.todos-list')).not_to have_content ' mentioned '
  end
end
