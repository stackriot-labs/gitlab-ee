/* eslint-disable */
((w) => {
  w.ResolveCount = Vue.extend({
    mixins: [DiscussionMixins],
    props: {
      loggedOut: Boolean
    },
    data: function () {
      return {
        discussions: CommentsStore.state
      };
    },
    computed: {
      allResolved: function () {
        return this.resolvedDiscussionCount === this.discussionCount;
      },
      resolvedCountText() {
        return this.discussionCount === 1 ? 'discussion' : 'discussions';
      }
    }
  });
})(window);
