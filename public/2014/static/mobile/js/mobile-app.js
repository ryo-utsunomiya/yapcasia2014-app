var myf7 = new Framework7();
var $$ = Framework7.$;
var yapc2014 = angular.module('yapc2014', ['ngSanitize']);

var get_current_date = function(){
  var default_date = '2014-08-28';
  var d = new Date();
  var localTime = d.getTime();
  var localOffset = d.getTimezoneOffset() * 60000;
  var utc = localTime + localOffset;
  var offset = +9.0;
  var result = utc - (3600000 * offset);
  var today = new Date(result);
  today = d.getFullYear() + '-' + ("0"+(d.getMonth()+1)).slice(-2) + '-' + d.getDate();
  var list = ['2014-08-28', '2014-08-29', '2014-08-30'];
  $.each(list, function(){
    if(today == this) default_date = this;
  });
  return default_date;
};

function get_param(key) {
  var url = location.href;
  parameters = url.split("?");
  params = parameters[1].split("&");
  var params_array = [];
  for ( i = 0; i < params.length; i++ ) {
    neet = params[i].split("=");
    params_array.push(neet[0]);
    params_array[neet[0]] = neet[1];
  }
  var value = params_array[key] || null;
  return value;
}

function set_param(key, value) {
  var uri = location.href;
  var re = new RegExp("([?&])" + key + "=.*?(&|$)");
  var separator = uri.indexOf('?') !== -1 ? "&" : "?";
  if (uri.match(re)) {
    uri = uri.replace(re, '$1' + key + "=" + value + '$2');
  }
  else {
    uri = uri + separator + key + "=" + value;
  }
  window.history.pushState(null,null,uri);
}

var current_date;
var param_date = get_param('date');
if(param_date) {
  var list = ['2014-08-28', '2014-08-29', '2014-08-30'];
  $.each(list, function(){
    if(param_date == this) current_date = this;
  });
}else{
  current_date = get_current_date();
}

yapc2014.directive("highlight", function() {
  return function(scope, element, attrs) {
    element.on('mouseleave', function(event) {
      element.removeClass(attrs.highlight)
    })
    element.on('mousedown', function(event) {
      element.addClass(attrs.highlight)
    })
  }
});

yapc2014.controller('DateController', function($scope){
  $scope.change_date = function(){
    $('.tab-link').each(function(){
      if($(this).attr('data-date') == current_date){
        $(this).addClass('active');
      }else{
        $(this).removeClass('active');
      }
    });
  };
  $('.tab-link').click(function(){
    current_date = $(this).attr('data-date');
    set_param('date', current_date);
    $scope.change_date();
    var scope = angular.element($('#schedule')).scope();
    scope.$apply(function(){
      scope.load();
    });
  });
});

yapc2014.controller('ScheduleController', function($scope, $http){
  var venue = {
    1 : 'Main Hall / 藤原洋記念ホール',
    2 : 'Sub Room1 / 多目的教室2',
    3 : 'Sub Room2 / 多目的教室3',
    4 : 'Event Hall / イベントホール'
  };
  $scope.load = function(){
    myf7.showPreloader();
    $http.get('/2014/talk/schedule?date=' + current_date + '&format=json').success(function(data) {
      var talks = [];
      $.each(data.talks_by_venue, function(){
        $.each(this, function(){
          var talk = this;
          var start_time = talk.start_on.match(/\d{2}:\d{2}/)[0];
          talk.start_time = start_time;
          talk.venue_name = venue[talk.venue_id];
          talks.push(talk);
        });
      });
      $.each(data.events_by_venue[3], function(){
        var talk = this;
        var start_time = talk.start_on.match(/\d{2}:\d{2}/)[0];
        talk.start_time = start_time;
        talk.venue_name = venue[talk.venue_id];
        talks.push(talk);
      });
      talks.sort(function(a,b){
        return a.start_time - b.start_time;
      });
      var talk_set = {};
      $.each(talks, function(){
        var talk = this;
        if ( talk_set[talk.start_time] == undefined ) {
          talk_set[talk.start_time] = [talk];
        }else{
          talk_set[talk.start_time].push(talk);
        }
      });
      $scope.talk_set = talk_set;
      myf7.hidePreloader();
    });
  };
});

yapc2014.controller('TalkController', function($scope, $element){
  $scope.detail = false;
  $scope.show_detail = function(id){
    var elem = angular.element('.talk-' + id).html();
    myf7.popup(elem);
  };
});

yapc2014.controller('ToolbarController', function($scope){
  $scope.scroll_to_top = function(){
    $('.page-content').animate({scrollTop: $('.messages').height() }, 'slow');
  };
  $scope.show_map = function(){
    var elem = angular.element('#map').html();
    console.log(elem);
    myf7.popup(elem);
  };
});
