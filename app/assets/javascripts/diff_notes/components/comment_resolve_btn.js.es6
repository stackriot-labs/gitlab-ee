/* eslint-disable */
(() => {
  const CommentAndResolveBtn = Vue.extend({
    props: {
      discussionId: String,
    },
    data() {
      return {
        textareaIsEmpty: true
      }
    },
    computed: {
      discussion: function () {
        return CommentsStore.state[this.discussionId];
      },
      showButton: function () {
        if (this.discussion) {
          return this.discussion.isResolvable();
        } else {
          return false;
        }
      },
      isDiscussionResolved: function () {
        return this.discussion.isResolved();
      },
      buttonText: function () {
        if (this.isDiscussionResolved) {
          if (this.textareaIsEmpty) {
            return "Unresolve discussion";
          } else {
            return "Comment & unresolve discussion";
          }
        } else {
          if (this.textareaIsEmpty) {
            return "Resolve discussion";
          } else {
            return "Comment & resolve discussion";
          }
        }
      }
    },
    mounted: function () {
      const $textarea = $(`#new-discussion-note-form-${this.discussionId} .note-textarea`);
      this.textareaIsEmpty = $textarea.val() === '';

      $textarea.on('input.comment-and-resolve-btn', () => {
        this.textareaIsEmpty = $textarea.val() === '';
      });
    },
    destroyed: function () {
      $(`#new-discussion-note-form-${this.discussionId} .note-textarea`).off('input.comment-and-resolve-btn');
    }
  });

  Vue.component('comment-and-resolve-btn', CommentAndResolveBtn);
})(window);
