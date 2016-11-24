/* eslint-disable func-names, space-before-function-paren, no-var, space-before-blocks, prefer-rest-params, wrap-iife, no-return-assign, padded-blocks, max-len */
(function() {
  var bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  this.NewCommitForm = (function() {
    function NewCommitForm(form) {
      this.renderDestination = bind(this.renderDestination, this);
      this.newBranch = form.find('.js-target-branch');
      this.originalBranch = form.find('.js-original-branch');
      this.createMergeRequest = form.find('.js-create-merge-request');
      this.createMergeRequestContainer = form.find('.js-create-merge-request-container');
      this.renderDestination();
      this.newBranch.keyup(this.renderDestination);
    }

    NewCommitForm.prototype.renderDestination = function() {
      var different;
      different = this.newBranch.val() !== this.originalBranch.val();
      if (different) {
        this.createMergeRequestContainer.show();
        if (!this.wasDifferent) {
          this.createMergeRequest.prop('checked', true);
        }
      } else {
        this.createMergeRequestContainer.hide();
        this.createMergeRequest.prop('checked', false);
      }
      return this.wasDifferent = different;
    };

    return NewCommitForm;

  })();

}).call(this);
