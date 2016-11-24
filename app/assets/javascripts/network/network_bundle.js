/* eslint-disable func-names, space-before-function-paren, prefer-arrow-callback, quotes, no-var, vars-on-top, camelcase, no-undef, comma-dangle, consistent-return, padded-blocks, max-len */
// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
/*= require_tree . */

(function() {
  $(function() {
    if (!$(".network-graph").length) return;

    var network_graph;
    network_graph = new Network({
      url: $(".network-graph").attr('data-url'),
      commit_url: $(".network-graph").attr('data-commit-url'),
      ref: $(".network-graph").attr('data-ref'),
      commit_id: $(".network-graph").attr('data-commit-id')
    });
    return new ShortcutsNetwork(network_graph.branch_graph);
  });

}).call(this);
