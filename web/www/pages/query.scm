(define-module (www pages query)
  #:use-module (www pages)
  #:export (page-query))

(define* (page-query request-path #:key (post-data ""))
  (page-root-template "sparqling-svs" request-path
   `((h2 "Query the database")
     (h3 "Query editor")
     (p "Use " (strong "Ctrl + Enter") " to execute the query.")
     (div (@ (id "editor"))
          "PREFIX faldo: <http://biohackathon.org/resource/faldo#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX : <http://localhost:5000/MyData/>

")
     (h4 "Authentication token")
     (p "Paste your authentication token below (if applicable).")
     (input (@ (id "oauth_token")
               (type "text")
               (name "token")
               (value "")))
     (script "
$(document).ready(function(){
  var editor = ace.edit('editor');
  var session = editor.getSession();
  editor.setTheme('ace/theme/github');
  editor.setShowPrintMargin(false);
  editor.setAutoScrollEditorIntoView(true);
  editor.setOptions({ maxLines: 120, minLines: 2 });
  session.setMode('ace/mode/sparql');
  session.setTabSize(2);

  /* Add keybindings for copying the text and for running the query. */
  editor.commands.addCommand({
    name: 'copyCommand',
    bindKey: {win: 'Ctrl-C',  mac: 'Command-C'},
    exec: function(editor) {
      $('#content').after('" (textarea (@ (id "copyText"))) "');
      var temp = document.getElementById('copyText');
      temp.value = editor.getSelectedText();
      temp.select();
      document.execCommand('copy');
      temp.remove();
      $('.ace_text-input').focus();
      }, readOnly: true
    });

  editor.commands.addCommand({
    name: 'executeQueryCommand',
    bindKey: {win: 'Ctrl-Enter',  mac: 'Command-Enter'},
    exec: function(editor) {
      $('#oauth_token').after(function(){ return '"
      (div (@ (class "query-data-loader"))
           (div (@ (class "title")) "Loading data ...")
           (div (@ (class "content")) "Please wait for the results to appear."))
      "' });

        /* Remove the previous query results. */
      $('.query-error').remove();
      $('#query-results').remove();
      $('#query-output').remove();
      $('#query-output_wrapper').remove();

      post_data = { query: editor.getValue(), token: oauth_token.value };
      $.post('/query-response', JSON.stringify(post_data), function (data){

        /*  Insert the results HTML table into the page. */
        $('#oauth_token').after(data);
        $('.query-data-loader').remove();

        /* Detect an error response. */
        if ($('.query-error').length == 0) {
          $('#oauth_token').after(function(){ return '" (h3 (@ (id "query-results")) "Query results") "' });

          /* Initialize DataTables. */
          $('#query-output').addClass('display');
          var dt = $('#query-output').DataTable({ sDom: 'lrtip' });
          dt.draw();
        }
      });
      }, readOnly: true
    });
});
"))
   #:dependencies '(ace jquery datatables)))
