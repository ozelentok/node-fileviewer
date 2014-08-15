// Generated by CoffeeScript 1.7.1
(function() {
  var DEFAULTS, FileServer, Validator, fileServer, formidable, fs, http, mime, path, settings, url, validator;

  http = require('http');

  url = require('url');

  path = require('path');

  fs = require('fs');

  mime = require('mime');

  formidable = require('formidable');

  DEFAULTS = {
    PORT: 8000,
    DIRECTORY: process.cwd(),
    CLIENT_DIR: path.join(__dirname, 'client')
  };

  FileServer = (function() {
    FileServer.prototype.dirRegex = new RegExp('^/dir/([^\0]*)$');

    FileServer.prototype.fileRegex = new RegExp('^/file/([^\0]+)$');

    function FileServer(settings) {
      this.publicDir = settings.directory;
      this.port = settings.port;
      this.clientDir = settings.clientDir;
    }

    FileServer.prototype.startServer = function() {
      http.createServer((function(_this) {
        return function(req, res) {
          var socketData, timeOfRequest, uri;
          uri = url.parse(req.url).pathname;
          uri = unescape(uri);
          socketData = req.socket.address();
          timeOfRequest = _this.getCurrentTime();
          console.log("" + socketData.address + " - " + timeOfRequest + " \"" + req.method + " " + uri + "\"");
          if (req.method === "GET") {
            _this.methodHandlerGET(req, res, uri);
          } else if (req.method === "POST") {
            _this.methodHandlerPOST(req, res, uri);
          } else {
            _this.sendMethodNotAllowed(res);
          }
        };
      })(this)).listen(this.port);
      console.log("Server serving on port " + this.port);
      return console.log("Folder used: " + this.publicDir);
    };

    FileServer.prototype.methodHandlerGET = function(req, res, uri) {
      var regexMatch;
      regexMatch = this.dirRegex.exec(uri);
      if (regexMatch !== null) {
        this.checkDirExistenceAndHandle(regexMatch[1], res);
        return;
      }
      regexMatch = this.fileRegex.exec(uri);
      if (regexMatch !== null) {
        this.checkFileExistenceAndHandle(regexMatch[1], res);
        return;
      }
      this.checkClientFileExistenceAndHandle(uri, res);
    };

    FileServer.prototype.methodHandlerPOST = function(req, res, uri) {
      var fileForm;
      fileForm = new formidable.IncomingForm();
      fileForm.uploadDir = path.join(this.publicDir, uri);
      fileForm.keepExtensions = true;
      fileForm.parse(req, (function(_this) {
        return function(err, fields, files) {
          var existingFilePath, renamedFilePath, uploadedFile;
          uploadedFile = files.uploadedFile;
          existingFilePath = uploadedFile.path;
          if (uploadedFile.name === '') {
            fs.unlink(existingFilePath, function(err) {
              _this.checkClientFileExistenceAndHandle(uri, res);
            });
          } else {
            renamedFilePath = path.join(fileForm.uploadDir, uploadedFile.name);
            fs.rename(existingFilePath, renamedFilePath, function(err) {
              _this.checkClientFileExistenceAndHandle(uri, res);
            });
          }
        };
      })(this));
    };

    FileServer.prototype.checkClientFileExistenceAndHandle = function(uri, res) {
      var realPath;
      if (uri === '/') {
        uri = 'index.html';
      }
      realPath = this.convertPath(this.clientDir, uri);
      if (!realPath) {
        this.sendErrorNotFound(res);
        return;
      }
      fs.stat(realPath, (function(_this) {
        return function(err, stats) {
          if (err) {
            _this.sendErrorInternal(res);
          } else if (stats.isDirectory()) {
            _this.sendErrorInternal(res);
          } else {
            _this.sendFile(realPath, res);
          }
        };
      })(this));
    };

    FileServer.prototype.convertPath = function(parentDir, uri) {
      var realPath;
      realPath = path.join(parentDir, uri);
      realPath = path.normalize(realPath);
      if (realPath.indexOf(parentDir) !== 0) {
        return false;
      }
      if (fs.existsSync(realPath)) {
        return realPath;
      } else {
        return false;
      }
    };

    FileServer.prototype.checkDirExistenceAndHandle = function(uri, res) {
      var realPath;
      realPath = this.convertPath(this.publicDir, uri);
      if (!realPath) {
        this.sendErrorNotFound(res);
        return;
      }
      fs.stat(realPath, (function(_this) {
        return function(err, stats) {
          if (err) {
            _this.sendErrorInternal(res);
          } else if (stats.isDirectory()) {
            _this.sendDirContents(realPath, res);
          } else {
            _this.sendErrorNotFound(res);
          }
        };
      })(this));
    };

    FileServer.prototype.checkFileExistenceAndHandle = function(uri, res) {
      var realPath;
      realPath = this.convertPath(this.publicDir, uri);
      if (!realPath) {
        this.sendErrorNotFound(res);
        return;
      }
      fs.stat(realPath, (function(_this) {
        return function(err, stats) {
          if (err) {
            _this.sendErrorInternal(res);
          } else if (stats.isFile()) {
            _this.sendFile(realPath, res);
          } else {
            _this.sendErrorNotFound(res);
          }
        };
      })(this));
    };

    FileServer.prototype.sendDirContents = function(realPath, res) {
      fs.readdir(realPath, (function(_this) {
        return function(err, files) {
          var dataToSend, fileSize, fileStats, i, isDir, uri, uriStart, _i, _ref;
          if (err) {
            _this.sendErrorInternal(res);
            return;
          }
          dataToSend = [];
          for (i = _i = 0, _ref = files.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
            fileStats = fs.statSync(path.join(realPath, files[i]));
            isDir = fileStats.isDirectory();
            uriStart = realPath.replace(_this.publicDir, '/');
            if (isDir) {
              fileSize = 0;
            } else {
              fileSize = fileStats.size;
            }
            uri = path.join(uriStart, files[i]);
            if (isDir) {
              uri += '/';
            }
            dataToSend[i] = {
              name: files[i],
              uri: uri,
              isDir: isDir,
              size: fileSize
            };
          }
          res.writeHead(200, {
            'Content-Type': 'application/json'
          });
          res.write(JSON.stringify(dataToSend));
          return res.end();
        };
      })(this));
    };

    FileServer.prototype.sendFile = function(filepath, res) {
      var stream;
      stream = fs.createReadStream(filepath);
      stream.on('open', function() {
        res.writeHead(200, {
          'Content-Type': mime.lookup(filepath)
        });
        return stream.pipe(res, {
          end: true
        });
      });
      stream.on('error', (function(_this) {
        return function(err) {
          return _this.sendErrorInternal();
        };
      })(this));
    };

    FileServer.prototype.sendErrorNotFound = function(res) {
      res.writeHead(404);
      return res.end();
    };

    FileServer.prototype.sendMethodNotAllowed = function(res) {
      res.writeHead(405);
      return res.end();
    };

    FileServer.prototype.sendErrorInternal = function(res) {
      res.writeHead(500);
      return res.end();
    };

    FileServer.prototype.getCurrentTime = function() {
      var currentTime;
      currentTime = new Date();
      return '[' + currentTime.getFullYear() + '-' + (currentTime.getMonth() + 1) + '-' + (currentTime.getDate()) + ' ' + (currentTime.getHours()) + ':' + (currentTime.getMinutes()) + ':' + currentTime.getSeconds() + ']';
    };

    return FileServer;

  })();

  Validator = (function() {
    function Validator() {}

    Validator.prototype.validateArgs = function() {
      var dir, port;
      dir = process.argv[2] || DEFAULTS.DIRECTORY;
      dir = path.resolve(dir, DEFAULTS.DIRECTORY);
      port = process.argv[3] || DEFAULTS.PORT;
      if (this.validatePathPort(dir, port)) {
        return {
          directory: dir,
          port: port,
          clientDir: DEFAULTS.CLIENT_DIR
        };
      }
      return false;
    };

    Validator.prototype.validatePathPort = function(dirpath, port) {
      if (!this.validateDir(dirpath)) {
        console.log('Directory path is bad');
        return false;
      }
      if (!this.validatePort(port)) {
        console.log('Port must be a number between 0 to 65535');
        return false;
      }
      return true;
    };

    Validator.prototype.validateDir = function(dirpath) {
      if (fs.existsSync(dirpath)) {
        return fs.statSync(dirpath).isDirectory();
      }
      return false;
    };

    Validator.prototype.validatePort = function(port) {
      var num;
      num = parseInt(port);
      if (isNaN(num)) {
        return false;
      }
      return num >= 0 && num <= 65535;
    };

    return Validator;

  })();

  validator = new Validator();

  settings = validator.validateArgs();

  if (settings) {
    fileServer = new FileServer(settings);
    fileServer.startServer();
  }

}).call(this);
