#autocompile
http = require 'http'
url = require 'url'
path = require 'path'
fs = require 'fs'
mime = require 'mime'

DEFAULTS =
	PORT: 8000,
	DIRECTORY: process.cwd()
	CLIENT_DIR: 'client'

class FileServer
	dirRegex: new RegExp('^/dir/([^\0]*)$')
	fileRegex: new RegExp('^/file/([^\0]+)$')

	constructor:(settings) ->
		@publicDir = settings.directory
		@port = settings.port
		@clientDir = settings.clientDir

	startServer: ->
		http.createServer((req, res) =>
			uri = url.parse(req.url).pathname
			uri = unescape(uri)

			socketData = req.socket.address()
			timeOfRequest = @getCurrentTime()
			console.log("#{socketData.address} - #{timeOfRequest} \"#{req.method} #{uri}\"")

			regexMatch = @dirRegex.exec(uri)
			if regexMatch isnt null
				#console.log "Sending Dir: #{uri}"
				@checkDirExistenceAndHandle(regexMatch[1], res)
				return

			regexMatch = @fileRegex.exec(uri)
			if regexMatch isnt null
				#console.log "Sending File: #{uri}"
				@checkFileExistenceAndHandle(regexMatch[1], res)
				return

			#console.log "Sending Client File: #{uri}"
			@checkClientFileExistenceAndHandle(uri, res)
			return
		).listen(@port)
		console.log "Server serving on port #{@port}"
		console.log "Folder used: #{@publicDir}"

	checkClientFileExistenceAndHandle: (uri, res) ->
		if uri is '/'
			uri = 'index.html'

		realPath = @convertPath(@clientDir, uri)
		if not realPath
			@sendErrorNotFound(res)
			return
		fs.stat(realPath, (err, stats) =>
			if err
				@sendErrorInternal(res)
			else if stats.isDirectory()
				@sendErrorInternal(res)
			else
				@sendFile(realPath, res)
			return
			)
		return

	convertPath: (parentDir, uri) ->
		realPath = path.join(parentDir, uri)
		realPath = path.normalize(realPath)
		if realPath.indexOf(parentDir) != 0
			return false
		if fs.existsSync(realPath) then return realPath else false

	checkDirExistenceAndHandle: (uri, res) ->
		realPath = @convertPath(@publicDir, uri)
		if not realPath
			@sendErrorNotFound(res)
			return
		fs.stat(realPath, (err, stats) =>
			if err
				@sendErrorInternal(res)
			else if stats.isDirectory()
				@sendDirContents(realPath, res)
			else
				@sendErrorNotFound(res)
			return
		)
		return

	checkFileExistenceAndHandle: (uri,  res) ->
		realPath = @convertPath(@publicDir, uri)
		if not realPath
			@sendErrorNotFound(res)
			return
		fs.stat(realPath, (err, stats) =>
			if err
				@sendErrorInternal(res)
			else if stats.isFile()
				@sendFile(realPath, res)
			else
				@sendErrorNotFound(res)
			return
		)
		return

	sendDirContents: (realPath, res) ->
		fs.readdir(realPath, (err, files) =>
			if err
				@sendErrorInternal(res)
				return
			dataToSend = []
			for i in [0...files.length]
				fileStats = fs.statSync(path.join(realPath, files[i]))
				isDir = fileStats.isDirectory()
				uriStart = realPath.replace(@publicDir, '/')
				if(isDir)
					fileSize = 0
				else
					fileSize = fileStats.size
				uri = path.join(uriStart, files[i])
				if isDir
					uri += '/'
				dataToSend[i] = {
					name: files[i]
					uri: uri
					isDir: isDir
					size: fileSize
				}
			res.writeHead(200, {'Content-Type': 'application/json'})
			res.write(JSON.stringify(dataToSend))
			res.end()
		)
		return

	sendFile: (filepath, res) ->
		stream = fs.createReadStream(filepath)
		res.writeHead(200, {'Content-Type': mime.lookup(filepath)})
		stream.pipe(res, {end:true})
		return

	sendErrorNotFound: (res) ->
		res.writeHead(404)
		res.end()

	sendErrorInternal: (res) ->
		res.writeHead(500)
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
		dir = path.resolve(dir, DEFAULTS.DIRECTORY)
		port = process.argv[3] || DEFAULTS.PORT
		if @validatePathPort(dir, port)
			return { directory: dir, port: port, clientDir : DEFAULTS.CLIENT_DIR}
		return false

	validatePathPort: (dirpath, port) ->
		if not @validateDir(dirpath)
			console.log('Directory path is bad')
			return false
		if not @validatePort(port)
			console.log('Port must be a number between 0 to 65535')
			return false
		return true

	validateDir: (dirpath) ->
		if fs.existsSync(dirpath)
			return fs.statSync(dirpath).isDirectory()
		return false

	validatePort: (port) ->
		num = parseInt(port)
		if isNaN(num)
			return false
		return num >= 0 and num <= 65535

validator = new Validator()
settings = validator.validateArgs()
if settings
	fileServer = new FileServer(settings)
	fileServer.startServer()
