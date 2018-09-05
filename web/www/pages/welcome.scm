(define-module (www pages welcome)
  #:use-module (www pages)
  #:use-module (www config)
  #:use-module (www util)
  #:use-module (www db connections)
  #:use-module (www db overview)
  #:use-module (sparql driver)
  #:use-module (web response)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-1)
  #:export (page-welcome))

(define* (page-welcome request-path #:key (post-data ""))
  (let ((number-of-endpoints (length (all-connections))))
    (page-root-template "Overview" request-path
     `((h2 "Overview")
       (div (@ (id "overview-plot-tooltip") (class "hidden")) "")
       (h3 "Cancer types")
       (div (@ (class "overview-plot-wrapper"))
         (p "Primary site")
         (svg (@ (id "tumor_types_plot") (style "width: 200px; height: 200px; background: #ffffff;"))))
       (h3 "Endpoint statistics")
       (p "There " ,(if (= number-of-endpoints 1) "is " "are ")
          ,number-of-endpoints " configured endpoint"
          ,(if (= number-of-endpoints 1) "" "s") ", which contain"
          ,(if (= number-of-endpoints 1) "s" "") ":")
       (div (@ (class "history-data-loader"))
            (div (@ (class "title")) "Loading overview ...")
            (div (@ (class "content")) "Please wait for the results to appear."))
       (script "
$(document).ready(function(){
  // Get data for the tumor types plot.
  $.get('/tumor-types.json', function(raw_data){

    var data = JSON.parse(raw_data);
    var width = $('#tumor_types_plot').width(),
        height = $('#tumor_types_plot').height(),
        radius = Math.min(width, height) / 2;
    var divNode = d3.select('body').node();
    var color = d3.scaleOrdinal()
        .range(['#98abc5', '#8a89a6', '#7b6888', '#6b486b', '#a05d56', '#d0743c', '#ff8c00']);

    var arc = d3.arc()
        .outerRadius(radius - 10)
        .innerRadius(0);

    var labelArc = d3.arc()
        .outerRadius(radius - 90)
        .innerRadius(radius - 90);

    var pie = d3.pie()
        .sort(null)
        .value(function(d) { return d.samples; });

    var svg = d3.select('#tumor_types_plot')
        .attr('width', width)
        .attr('height', height)
        .append('g')
        .attr('transform', 'translate(' + width / 2 + ',' + height / 2 + ')');

    var g = svg.selectAll('.arc')
        .data(pie(data))
        .enter().append('g')
        .attr('class', 'arc');

    g.append('path')
        .attr('d', arc)
        .style('fill', function(d) { return color(d.data.name); })
        .on('mousemove', function(d) {
            d3.select(this).attr('opacity', '0.7');
            var mousePos = d3.mouse(divNode);
            d3.select('#overview-plot-tooltip')
                .style('left', mousePos[0] + 10 + 'px')
                .style('top',  mousePos[1] - 40 + 'px')
                .select('#value')
                .attr('text-anchor', 'middle');
            d3.select('#overview-plot-tooltip')
                .classed('hidden', false)
                .html(''+ d.data.name +' ('+ d.data.samples +' samples)'); })
        .on('mouseout', function(d){
            d3.select(this).attr('opacity', '1.0');
            d3.select('#overview-plot-tooltip').classed('hidden', true); });
  });

  // Get data for the overview table.
  $.get('/overview-table', function(data){
    $('.history-data-loader').replaceWith(data);
  });
});"))
     #:dependencies '(jquery d3))))
