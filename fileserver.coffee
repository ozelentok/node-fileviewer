#autocompile
http = require 'http'
url = require 'url'
path = require 'path'
fs = require 'fs'
mime = require 'mime'
jade = require 'jade'
formidable = require 'formidable'

DEFAULTS =
	PORT: 8000,
	DIRECTORY: process.cwd()
	CLIENT_DIR: path.join(__dirname, 'client')

class FileServer

	constructor: (settings) ->
		@publicDir = settings.directory
		@port = settings.port
		@clientDir = settings.clientDir
		@dirIndexTemplate = jade.compileFile path.join(@clientDir, 'index.jade')

	startServer: ->
		httpServer = http.createServer (req, res) =>
			uri = url.parse(req.url).pathname
			uri = unescape(uri)

			socketData = req.socket.address()
			timeOfRequest = @getCurrentTime()
			console.log "#{socketData.address} - #{timeOfRequest} \"#{req.method} #{uri}\""

			if req.method is "GET"
				@methodHandlerGET(res, uri)
			else if req.method is "POST"
				@methodHandlerPOST(req, res, uri)
			else
				@sendMethodNotAllowed(res)
			return

		httpServer.listen @port
		console.log "Server serving on port #{@port}"
		console.log "Folder used: #{@publicDir}"
		return

	methodHandlerGET: (res, uri) ->
		systemPath = @uriToSystemPath uri
		if systemPath[systemPath.length - 1] is '/' and systemPath isnt '/'
			systemPath = systemPath[0...systemPath.length - 1]
		if not systemPath
			@sendErrorNotFound res
			return
		fs.stat systemPath, (err, stats) =>
			if err
				@sendErrorInternal res
			else if stats.isFile()
				@sendFile res, systemPath
			else
				@sendDirIndex res, systemPath
			return
		return

	methodHandlerPOST: (req, res, uri) ->
		fileForm = new formidable.IncomingForm()
		fileForm.uploadDir = path.join(@publicDir, uri)
		fileForm.keepExtensions = true
		fileForm.parse req, (err, fields, files) =>
			uploadedFile = files.uploadedFile
			existingFilePath = uploadedFile.path
			if uploadedFile.name is ''
				fs.unlink existingFilePath, (err) =>
					@checkClientFileExistenceAndHandle(uri, res)
					return
			else
				renamedFilePath = path.join(fileForm.uploadDir, uploadedFile.name)
				fs.rename existingFilePath, renamedFilePath, (err) =>
					@checkClientFileExistenceAndHandle(uri, res)
					return
			return
		return

	uriToSystemPath: (uri) ->
		realPath = path.join(@publicDir, uri)
		realPath = path.normalize(realPath)
		if realPath.indexOf(@publicDir) != 0
			return false
		if fs.existsSync(realPath) then return realPath else false

	generateIndexHTML: (path, filesMetaData)->
		return @dirIndexTemplate({path: path, filesMetaData: filesMetaData})

	sendDirIndex: (res, systemPath) ->
		fs.readdir systemPath, (err, files) =>
			if err
				@sendErrorInternal(res)
				return
			filesMetaData = []
			for i in [0...files.length]
				fileStats = fs.statSync(path.join(systemPath, files[i]))
				isDir = fileStats.isDirectory()
				if systemPath is @publicDir
					parentDir = systemPath.replace(@publicDir, '/')
				else
					parentDir = systemPath.replace(@publicDir, '')
				if isDir
					fileSize = 0
				else
					fileSize = fileStats.size
				uri = path.join(parentDir, files[i])
				filesMetaData[i] = {
					name: files[i]
					uri: uri
					isDir: isDir
					size: @humanSize(fileSize)
				}
			filesMetaData.sort (a, b) ->
				if a.isDir
					if b.isDir
						return a.name.toLowerCase() > b.name.toLowerCase()
					else
						return -1
				if b.isDir
					return 1
				return a.name.toLowerCase() > b.name.toLowerCase()

			if parentDir isnt '/'
				for i in [parentDir.length - 2..0] by -1
					if parentDir[i] is '/'
						upDirUri = parentDir[0...i]
						upDirUri = if upDirUri then upDirUri else '/'
						filesMetaData.splice 0, 0, {
							name: 'Go up in directory tree'
							uri: upDirUri
							isDir: true
							size: 0
						}
						break
			res.writeHead 200, {'Content-Type': 'text/html' }
			res.write @generateIndexHTML(parentDir, filesMetaData)
			res.end()
			return
		return

	humanSize: (size) ->
		types = ['Bytes', 'KB', 'MB']
		for type in types
			if(size < 1024)
				return "#{size.toFixed(1)} #{type}"
			else
				size /= 1024
		return "#{size.toFixed(1)} GB"

	sendFile: (res, systemPath) ->
		stream = fs.createReadStream(systemPath)
		stream.on 'open', ->
			res.writeHead(200, {'Content-Type': mime.lookup(systemPath)})
			stream.pipe(res, {end:true})
			return
		stream.on 'error', (err) =>
			@sendErrorInternal()
			return
		return

	sendErrorNotFound: (res) ->
		res.writeHead 404
		res.end()

	sendMethodNotAllowed: (res) ->
		res.writeHead 405
		res.end()

	sendErrorInternal: (res) ->
		res.writeHead 500
		res.end()

	getCurrentTime: ->
		currentTime = new Date()
		return '[' + currentTime.getFullYear() + '-' +
				(currentTime.getMonth() + 1) + '-' +
				(currentTime.getDate()) + ' ' +
				(currentTime.getHours()) + ':' +
				(currentTime.getMinutes()) + ':' +
				currentTime.getSeconds() + ']'

class Validator

	validateArgs: ->
		dir = process.argv[2] || DEFAULTS.DIRECTORY
		dir = path.resolve dir, DEFAULTS.DIRECTORY
		port = process.argv[3] || DEFAULTS.PORT
		if @validatePathPort dir, port
			return { directory: dir, port: port, clientDir : DEFAULTS.CLIENT_DIR}
		return false

	validatePathPort: (dirpath, port) ->
		if not @validateDir(dirpath)
			console.log 'Directory path is bad'
			return false
		if not @validatePort(port)
			console.log 'Port must be a number between 0 to 65535'
			return false
		return true

	validateDir: (dirpath) ->
		if fs.existsSync dirpath
			return fs.statSync(dirpath).isDirectory()
		return false

	validatePort: (port) ->
		num = parseInt port
		if isNaN num
			return false
		return num >= 0 and num <= 65535

validator = new Validator()
settings = validator.validateArgs()
if settings
	fileServer = new FileServer settings
	fileServer.startServer()
