// Generated by CoffeeScript 1.6.3
(function() {
  var App;

  App = (function() {
    function App() {
      this.$file_list = $('#file_list');
      this.dirAjaxHandler('/dir/');
    }

    App.prototype.dirAjaxHandler = function(uri) {
      var _this = this;
      return $.ajax({
        url: uri,
        type: 'GET',
        dataType: 'json',
        success: function(data) {
          return _this.appendDirContents(data);
        }
      });
    };

    App.prototype.appendDirContents = function(data) {
      var counter, file, _i, _len, _results;
      counter = 0;
      this.$file_list.empty();
      _results = [];
      for (_i = 0, _len = data.length; _i < _len; _i++) {
        file = data[_i];
        if (file.isDir) {
          this.appendDirToList(file, 'dir' + counter);
          _results.push(counter += 1);
        } else {
          _results.push(this.appendFileToList(file));
        }
      }
      return _results;
    };

    App.prototype.appendFileToList = function(fileData) {
      return this.$file_list.append("<li><a href=\"" + fileData.uri + "\">" + fileData.name + "</a></li>");
    };

    App.prototype.appendDirToList = function(dirData, id) {
      var _this = this;
      this.$file_list.append("<li><span class=\"dirLink\" id=\"" + id + "\">" + dirData.name + "</span></li>");
      return $("#" + id).click(function() {
        return _this.dirAjaxHandler(dirData.uri);
      });
    };

    return App;

  })();

  $(document).ready(function() {
    var app;
    return app = new App();
  });

}).call(this);
