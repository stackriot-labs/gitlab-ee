/* eslint-disable */
//= require jquery
//= require jquery_ujs
//= require js.cookie
//= require vue
//= require vue-resource
//= require lib/utils/url_utility
//= require boards/models/issue
//= require boards/models/label
//= require boards/models/list
//= require boards/models/user
//= require boards/services/board_service
//= require boards/stores/boards_store
//= require ./mock_data

describe('Store', () => {
  beforeEach(() => {
    Vue.http.interceptors.push(boardsMockInterceptor);
    gl.boardService = new BoardService('/test/issue-boards/board', '1');
    gl.issueBoards.BoardsStore.create();

    Cookies.set('issue_board_welcome_hidden', 'false', {
      expires: 365 * 10,
      path: ''
    });
  });

  afterEach(() => {
    Vue.http.interceptors = _.without(Vue.http.interceptors, boardsMockInterceptor);
  });

  it('starts with a blank state', () => {
    expect(gl.issueBoards.BoardsStore.state.lists.length).toBe(0);
  });

  describe('lists', () => {
    it('creates new list without persisting to DB', () => {
      gl.issueBoards.BoardsStore.addList(listObj);

      expect(gl.issueBoards.BoardsStore.state.lists.length).toBe(1);
    });

    it('finds list by ID', () => {
      gl.issueBoards.BoardsStore.addList(listObj);
      const list = gl.issueBoards.BoardsStore.findList('id', 1);

      expect(list.id).toBe(1);
    });

    it('finds list by type', () => {
      gl.issueBoards.BoardsStore.addList(listObj);
      const list = gl.issueBoards.BoardsStore.findList('type', 'label');

      expect(list).toBeDefined();
    });

    it('finds list limited by type', () => {
      gl.issueBoards.BoardsStore.addList({
        id: 1,
        position: 0,
        title: 'Test',
        list_type: 'backlog'
      });
      const list = gl.issueBoards.BoardsStore.findList('id', 1, 'backlog');

      expect(list).toBeDefined();
    });

    it('gets issue when new list added', (done) => {
      gl.issueBoards.BoardsStore.addList(listObj);
      const list = gl.issueBoards.BoardsStore.findList('id', 1);

      expect(gl.issueBoards.BoardsStore.state.lists.length).toBe(1);

      setTimeout(() => {
        expect(list.issues.length).toBe(1);
        expect(list.issues[0].id).toBe(1);
        done();
      }, 0);
    });

    it('persists new list', (done) => {
      gl.issueBoards.BoardsStore.new({
        title: 'Test',
        type: 'label',
        label: {
          id: 1,
          title: 'Testing',
          color: 'red',
          description: 'testing;'
        }
      });
      expect(gl.issueBoards.BoardsStore.state.lists.length).toBe(1);

      setTimeout(() => {
        const list = gl.issueBoards.BoardsStore.findList('id', 1);
        expect(list).toBeDefined();
        expect(list.id).toBe(1);
        expect(list.position).toBe(0);
        done();
      }, 0);
    });

    it('check for blank state adding', () => {
      expect(gl.issueBoards.BoardsStore.shouldAddBlankState()).toBe(true);
    });

    it('check for blank state not adding', () => {
      gl.issueBoards.BoardsStore.addList(listObj);
      expect(gl.issueBoards.BoardsStore.shouldAddBlankState()).toBe(false);
    });

    it('check for blank state adding when backlog & done list exist', () => {
      gl.issueBoards.BoardsStore.addList({
        list_type: 'backlog'
      });
      gl.issueBoards.BoardsStore.addList({
        list_type: 'done'
      });

      expect(gl.issueBoards.BoardsStore.shouldAddBlankState()).toBe(true);
    });

    it('adds the blank state', () => {
      gl.issueBoards.BoardsStore.addBlankState();

      const list = gl.issueBoards.BoardsStore.findList('type', 'blank', 'blank');
      expect(list).toBeDefined();
    });

    it('removes list from state', () => {
      gl.issueBoards.BoardsStore.addList(listObj);

      expect(gl.issueBoards.BoardsStore.state.lists.length).toBe(1);

      gl.issueBoards.BoardsStore.removeList(1, 'label');

      expect(gl.issueBoards.BoardsStore.state.lists.length).toBe(0);
    });

    it('moves the position of lists', () => {
      const listOne = gl.issueBoards.BoardsStore.addList(listObj),
            listTwo = gl.issueBoards.BoardsStore.addList(listObjDuplicate);

      expect(gl.issueBoards.BoardsStore.state.lists.length).toBe(2);

      gl.issueBoards.BoardsStore.moveList(listOne, ['2', '1']);

      expect(listOne.position).toBe(1);
    });

    it('moves an issue from one list to another', (done) => {
      const listOne = gl.issueBoards.BoardsStore.addList(listObj),
            listTwo = gl.issueBoards.BoardsStore.addList(listObjDuplicate);

      expect(gl.issueBoards.BoardsStore.state.lists.length).toBe(2);

      setTimeout(() => {
        expect(listOne.issues.length).toBe(1);
        expect(listTwo.issues.length).toBe(1);

        gl.issueBoards.BoardsStore.moveIssueToList(listOne, listTwo, listOne.findIssue(1));

        expect(listOne.issues.length).toBe(0);
        expect(listTwo.issues.length).toBe(1);

        done();
      }, 0);
    });
  });
});
