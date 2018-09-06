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
       (div (@ (id "plots-wrapper"))
            (div (@ (id "tumor-types-plot-wrapper")
                    (class "overview-plot-wrapper hidden"))
                 (p "Primary site")
                 (svg (@ (id "tumor-types-plot") (style "width: 200px; height: 200px;"))))
            (div (@ (id "birthyear-distribution-plot-wrapper")
                    (class "overview-plot-wrapper hidden"))
                 (p "Samples per birthyear")
                 (svg (@ (id "birthyear-distribution-plot")
                         (style "margin-left: 40px; width: 700px; height: 200px;")))))
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
  var divNode = d3.select('body').node();

  // Get data for the tumor types plot.
  $.get('/tumor-types.json', function(raw_data){

    var data = JSON.parse(raw_data);
    var width = $('#tumor-types-plot').width(),
        height = $('#tumor-types-plot').height(),
        radius = Math.min(width, height) / 2;

    var color = d3.scaleOrdinal()
        .range(['#3d9970', '#98abc5', '#8a89a6', '#85144b', '#7b6888',
                '#6b486b', '#a05d56', '#d0743c', '#ff8c00', '#ffdc00',
                '#b10dc9', '#333333', '#cccccc']);

    var arc = d3.arc()
        .outerRadius(radius - 10)
        .innerRadius(0);

    var labelArc = d3.arc()
        .outerRadius(radius - 90)
        .innerRadius(radius - 90);

    var pie = d3.pie()
        .sort(null)
        .value(function(d) { return d.samples; });

    var svg = d3.select('#tumor-types-plot')
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

     $('#tumor-types-plot-wrapper').removeClass('hidden');
  });

  // Get the number of samples per year.
  $.get('/birthyear-distribution.json', function(raw_data){
    var data = JSON.parse(raw_data);
    var margin = { top: 20, right: 20, bottom: 20, left:20 },
        width  = $('#birthyear-distribution-plot').width() - margin.left - margin.right,
        height = $('#birthyear-distribution-plot').height() - margin.top - margin.bottom;

    var x = d3.scaleBand().rangeRound([0, width]).padding(0.1),
        y = d3.scaleLinear().rangeRound([height, 20]);

    x.domain(data.map(function(d) { return d.birthyear; }));
    y.domain([0, d3.max(data, function(d) { return d.samples; })]);

    var svg = d3.select('#birthyear-distribution-plot');
    // append the rectangles for the bar chart
    svg.selectAll('.bar')
      .data(data)
      .enter().append('rect')
      .attr('class', 'bar')
      .attr('x', function(d) { return x(d.birthyear); })
      .attr('width', x.bandwidth())
      .attr('y', function(d) { return y(d.samples); })
      .attr('height', function(d) { return height - y(d.samples); })
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
                .html(''+ d.birthyear +' ('+ d.samples +')'); })
        .on('mouseout', function(d){
            d3.select(this).attr('opacity', '1.0');
            d3.select('#overview-plot-tooltip').classed('hidden', true); });

    // add the x Axis
    svg.append('g')
      .attr('transform', 'translate(0,' + height + ')')
      .call(d3.axisBottom(x))
      .selectAll('text')
        .attr('y', 0)
        .attr('x', 9)
        .attr('dy', '.35em')
        .attr('transform', 'rotate(90)')
        .style('text-anchor', 'start')
        .style('margin-left', '20px')
        .style('font-size', '8px');

    // add the y Axis
    svg.append('g').call(d3.axisLeft(y));
    $('#birthyear-distribution-plot-wrapper').removeClass('hidden');
  });

  // Get data for the overview table.
  $.get('/overview-table', function(data){
    $('.history-data-loader').replaceWith(data);
  });
});"))
     #:dependencies '(jquery d3))))
