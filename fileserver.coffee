#autocompile
http = require 'http'
url = require 'url'
path = require 'path'
fs = require 'fs'
mime = require 'mime'

DEFAULTS =
	PORT: 8000,
	DIRECTORY: process.cwd()

class FileServer
	dirRegex: new RegExp('^/dir/([^\0]*)$')
	fileRegex: new RegExp('^/file/([^\0]+)$')
	constructor:(settings) ->
		@publicDir = settings.directory
		@port = settings.port
		@clientDir = settings.clientDir || 'client'

	startServer: ->
		http.createServer((req, res) =>
			uri = url.parse(req.url).pathname
			uri = unescape(uri)
			regexMatch = @dirRegex.exec(uri)
			socketData = req.socket.address()
			timeOfRequest = @getCurrentTime()
			console.log("#{socketData.address} - #{timeOfRequest} \"#{req.method} #{uri}\"")
			if regexMatch isnt null
				console.log "Sending Dir: #{uri}"
				@checkDirExistenceAndHandle(regexMatch[1], res)
				return
			regexMatch = @fileRegex.exec(uri)
			if regexMatch isnt null
				console.log "Sending File: #{uri}"
				@checkFileExistenceAndHandle(regexMatch[1], res)
				return
			console.log "Sending Client File: #{uri}"
			@checkClientFileExistenceAndHandle(uri, res)
			return
		).listen(@port)
		console.log "Server serving on port #{@port}"
		console.log "Folder used: #{@publicDir}"

	checkClientFileExistenceAndHandle: (clientUri, res) ->
		if (clientUri is '/')
			clientUri = 'index.html'
		realPath = path.join(@clientDir, clientUri)
		realPath = path.normalize(realPath)
		if realPath.indexOf(@clientDir) != 0
			@sendErrorNotFound(res)
			return
		fs.exists(realPath, (doesExist) =>
			if (not doesExist)
				@sendErrorNotFound(res)
				return
			fs.stat(realPath, (err, stats) =>
				if(err)
					@sendErrorInternal(res)
				else if(stats.isDirectory())
					@sendErrorInternal(res)
				else
					@sendClient(realPath, res)
			)
			return
		)
		return

	checkDirExistenceAndHandle: (dirUri, res) ->
		realPath = path.join(@publicDir, dirUri)
		realPath = path.normalize(realPath)
		if realPath.indexOf(@publicDir) != 0
			@sendErrorNotFound(res)
			return
		fs.exists(realPath, (doesExist) =>
			if(not doesExist)
				@sendErrorNotFound(res)
				return
			fs.stat(realPath, (err, stats) =>
				if(err)
					@sendErrorInternal(res)
				else if(stats.isDirectory())
					@sendDirContents(realPath, res)
				else
					@sendErrorNotFound(res)
			)
			return
		)
		return
	checkFileExistenceAndHandle: (fileUri,  res) ->
		realPath = path.join(@publicDir, fileUri)
		realPath = path.normalize(realPath)
		if realPath.indexOf(@publicDir) != 0
			@sendErrorNotFound(res)
			return
		fs.exists(realPath, (doesExist) =>
			if(not doesExist)
				@sendErrorNotFound(res)
				return
			fs.stat(realPath, (err, stats) =>
				if(err)
					@sendErrorNotFound(res)
				else if(stats.isFile())
					@sendFile(realPath, res)
				else
					@sendErrorNotFound(res)
			)
			return
		)
		return

	sendClient: (realPath, res) ->
		fs.readFile(realPath, (err, data) =>
			if(err)
				@sendErrorInternal(res)
				return
			res.writeHead(200, {'Content-Type': mime.lookup(realPath)})
			res.write(data)
			res.end()
		)
		return
	sendDirContents: (realPath, res) ->
		fs.readdir(realPath, (err, files) =>
			if(err)
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
			return { directory: dir, port: port }
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
		if num < 0 || num > 65535
			return false
		return true

validator = new Validator()
settings = validator.validateArgs()
if settings
	fileServer = new FileServer(settings)
	fileServer.startServer()
