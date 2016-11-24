require 'rails_helper'

describe API::API, api: true do
  include ApiHelpers

  let(:project) { create(:empty_project, :public) }
  let(:admin) { create(:admin) }

  describe 'GET /projects/:project_id/snippets/:id' do
    # TODO (rspeicher): Deprecated; remove in 9.0
    it 'always exposes expires_at as nil' do
      snippet = create(:project_snippet, author: admin)

      get api("/projects/#{snippet.project.id}/snippets/#{snippet.id}", admin)

      expect(json_response).to have_key('expires_at')
      expect(json_response['expires_at']).to be_nil
    end
  end

  describe 'GET /projects/:project_id/snippets/' do
    let(:user) { create(:user) }

    it 'returns all snippets available to team member' do
      project.team << [user, :developer]
      public_snippet = create(:project_snippet, :public, project: project)
      internal_snippet = create(:project_snippet, :internal, project: project)
      private_snippet = create(:project_snippet, :private, project: project)

      get api("/projects/#{project.id}/snippets/", user)

      expect(response).to have_http_status(200)
      expect(json_response.size).to eq(3)
      expect(json_response.map{ |snippet| snippet['id']} ).to include(public_snippet.id, internal_snippet.id, private_snippet.id)
      expect(json_response.last).to have_key('web_url')
    end

    it 'hides private snippets from regular user' do
      create(:project_snippet, :private, project: project)

      get api("/projects/#{project.id}/snippets/", user)
      expect(response).to have_http_status(200)
      expect(json_response.size).to eq(0)
    end
  end

  describe 'POST /projects/:project_id/snippets/' do
    let(:params) do
      {
        title: 'Test Title',
        file_name: 'test.rb',
        code: 'puts "hello world"',
        visibility_level: Gitlab::VisibilityLevel::PUBLIC
      }
    end

    it 'creates a new snippet' do
      post api("/projects/#{project.id}/snippets/", admin), params

      expect(response).to have_http_status(201)
      snippet = ProjectSnippet.find(json_response['id'])
      expect(snippet.content).to eq(params[:code])
      expect(snippet.title).to eq(params[:title])
      expect(snippet.file_name).to eq(params[:file_name])
      expect(snippet.visibility_level).to eq(params[:visibility_level])
    end

    it 'returns 400 for missing parameters' do
      params.delete(:title)

      post api("/projects/#{project.id}/snippets/", admin), params

      expect(response).to have_http_status(400)
    end
  end

  describe 'PUT /projects/:project_id/snippets/:id/' do
    let(:snippet) { create(:project_snippet, author: admin) }

    it 'updates snippet' do
      new_content = 'New content'

      put api("/projects/#{snippet.project.id}/snippets/#{snippet.id}/", admin), code: new_content

      expect(response).to have_http_status(200)
      snippet.reload
      expect(snippet.content).to eq(new_content)
    end

    it 'returns 404 for invalid snippet id' do
      put api("/projects/#{snippet.project.id}/snippets/1234", admin), title: 'foo'

      expect(response).to have_http_status(404)
      expect(json_response['message']).to eq('404 Snippet Not Found')
    end

    it 'returns 400 for missing parameters' do
      put api("/projects/#{project.id}/snippets/1234", admin)

      expect(response).to have_http_status(400)
    end
  end

  describe 'DELETE /projects/:project_id/snippets/:id/' do
    let(:snippet) { create(:project_snippet, author: admin) }

    it 'deletes snippet' do
      admin = create(:admin)
      snippet = create(:project_snippet, author: admin)

      delete api("/projects/#{snippet.project.id}/snippets/#{snippet.id}/", admin)

      expect(response).to have_http_status(200)
    end

    it 'returns 404 for invalid snippet id' do
      delete api("/projects/#{snippet.project.id}/snippets/1234", admin)

      expect(response).to have_http_status(404)
      expect(json_response['message']).to eq('404 Snippet Not Found')
    end
  end

  describe 'GET /projects/:project_id/snippets/:id/raw' do
    let(:snippet) { create(:project_snippet, author: admin) }

    it 'returns raw text' do
      get api("/projects/#{snippet.project.id}/snippets/#{snippet.id}/raw", admin)

      expect(response).to have_http_status(200)
      expect(response.content_type).to eq 'text/plain'
      expect(response.body).to eq(snippet.content)
    end

    it 'returns 404 for invalid snippet id' do
      delete api("/projects/#{snippet.project.id}/snippets/1234", admin)

      expect(response).to have_http_status(404)
      expect(json_response['message']).to eq('404 Snippet Not Found')
    end
  end
end
