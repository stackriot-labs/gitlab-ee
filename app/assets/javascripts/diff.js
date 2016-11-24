/* eslint-disable func-names, space-before-function-paren, wrap-iife, no-var, max-len, one-var, camelcase, one-var-declaration-per-line, no-unused-vars, no-unused-expressions, no-sequences, object-shorthand, comma-dangle, prefer-arrow-callback, semi, radix, padded-blocks, max-len */
(function() {
  this.Diff = (function() {
    var UNFOLD_COUNT;

    UNFOLD_COUNT = 20;

    function Diff() {
      $('.files .diff-file').singleFileDiff();
      this.filesCommentButton = $('.files .diff-file').filesCommentButton();
      if (this.diffViewType() === 'parallel') {
        $('.content-wrapper .container-fluid').removeClass('container-limited');
      }
      $(document).off('click', '.js-unfold');
      $(document).on('click', '.js-unfold', (function(_this) {
        return function(event) {
          var line_number, link, file, offset, old_line, params, prev_new_line, prev_old_line, ref, ref1, since, target, to, unfold, unfoldBottom;
          target = $(event.target);
          unfoldBottom = target.hasClass('js-unfold-bottom');
          unfold = true;
          ref = _this.lineNumbers(target.parent()), old_line = ref[0], line_number = ref[1];
          offset = line_number - old_line;
          if (unfoldBottom) {
            line_number += 1;
            since = line_number;
            to = line_number + UNFOLD_COUNT;
          } else {
            ref1 = _this.lineNumbers(target.parent().prev()), prev_old_line = ref1[0], prev_new_line = ref1[1];
            line_number -= 1;
            to = line_number;
            if (line_number - UNFOLD_COUNT > prev_new_line + 1) {
              since = line_number - UNFOLD_COUNT;
            } else {
              since = prev_new_line + 1;
              unfold = false;
            }
          }
          file = target.parents('.diff-file');
          link = file.data('blob-diff-path');
          params = {
            since: since,
            to: to,
            bottom: unfoldBottom,
            offset: offset,
            unfold: unfold,
            view: file.data('view')
          };
          return $.get(link, params, function(response) {
            return target.parent().replaceWith(response);
          });
        };
      })(this));
    }

    Diff.prototype.diffViewType = function() {
      return $('.inline-parallel-buttons a.active').data('view-type');
    }

    Diff.prototype.lineNumbers = function(line) {
      if (!line.children().length) {
        return [0, 0];
      }

      return line.find('.diff-line-num').map(function() {
        return parseInt($(this).data('linenumber'));
      });
    };

    return Diff;

  })();

}).call(this);
