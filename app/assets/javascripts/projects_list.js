/* eslint-disable func-names, space-before-function-paren, object-shorthand, quotes, no-var, one-var, one-var-declaration-per-line, no-undef, prefer-arrow-callback, consistent-return, no-unused-vars, camelcase, prefer-template, comma-dangle, padded-blocks, max-len */
(function() {
  this.ProjectsList = {
    init: function() {
      $(".projects-list-filter").off('keyup');
      this.initSearch();
      return this.initPagination();
    },
    initSearch: function() {
      var debounceFilter, projectsListFilter;
      projectsListFilter = $('.projects-list-filter');
      debounceFilter = _.debounce(ProjectsList.filterResults, 500);
      return projectsListFilter.on('keyup', function(e) {
        if (projectsListFilter.val() !== '') {
          return debounceFilter();
        }
      });
    },
    filterResults: function() {
      var form, project_filter_url, search;
      $('.projects-list-holder').fadeTo(250, 0.5);
      form = null;
      form = $("form#project-filter-form");
      search = $(".projects-list-filter").val();
      project_filter_url = form.attr('action') + '?' + form.serialize();
      return $.ajax({
        type: "GET",
        url: form.attr('action'),
        data: form.serialize(),
        complete: function() {
          return $('.projects-list-holder').fadeTo(250, 1);
        },
        success: function(data) {
          $('.projects-list-holder').replaceWith(data.html);
          return history.replaceState({
            page: project_filter_url
          // Change url so if user reload a page - search results are saved
          }, document.title, project_filter_url);
        },
        dataType: "json"
      });
    },
    initPagination: function() {
      return $('.projects-list-holder .pagination').on('ajax:success', function(e, data) {
        return $('.projects-list-holder').replaceWith(data.html);
      });
    }
  };

}).call(this);
