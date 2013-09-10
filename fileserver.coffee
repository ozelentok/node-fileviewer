#autocompile
http = require 'http'
url = require 'url'
path = require 'path'
fs = require 'fs'
class FileServer
	clientFilePaths: {
		'/': 'client/index.html'
		'/style.css': 'client/style.css'
		'/fs.js': 'client/fs.js'
	}
	clientContentTypes: {
		'/': 'text/html'
		'/style.css': 'text/css'
		'/fs.js' : 'application/javascript'
	}
	dirRegex: new RegExp('^/dir/([a-zA-Z0-9_ /\.]*)$')
	fileRegex: new RegExp('^/file/([a-zA-Z0-9_ /\.]+)$')
	constructor:(@port, @publicDir) ->

	startServer: ->
		http.createServer( (req, res) =>
			uri = url.parse(req.url).pathname
			uri = unescape(uri)
			if(@clientFilePaths.hasOwnProperty(uri))
				console.log "Sending Client File: #{uri}"
				@sendClient(uri, res)
				return
			regexMatch = @dirRegex.exec(uri)
			if(regexMatch != null)
				console.log "Sending Dir: #{uri}"
				realPath = path.join(@publicDir, regexMatch[1])
				@checkDirExistenceAndHandle(realPath, res)
				return
			regexMatch = @fileRegex.exec(uri)
			if(regexMatch != null)
				console.log "Sending File: #{uri}"
				realPath = path.join(@publicDir, regexMatch[1])
				@checkFileExistenceAndHandle(realPath, res)
				return
			@sendErrorNotFound(res)
		).listen(@port)
		console.log "Server open on port #{@port}"
		console.log "Folder used: #{@publicDir}"
	
	checkDirExistenceAndHandle: (realPath, res) ->
		fs.exists(realPath, (doesExist) =>
			if(not doesExist)
				@sendErrorNotFound(res)
				return
			fs.stat(realPath,  (err, stats) =>
				if(err)
					@sendErrorNotFound(res)
				else if(stats.isDirectory())
					@sendDirContents(realPath,  res)
				else
					@sendErrorNotFound(res)
			)
			return
		)
		return
	checkFileExistenceAndHandle: (realPath,  res) ->
		fs.exists(realPath, (doesExist) =>
			if(not doesExist)
				@sendErrorNotFound(res)
				return
			fs.stat(realPath,  (err, stats) =>
				if(err)
					@sendErrorNotFound(res)
				else if(stats.isFile())
					@sendFile(realPath,  res)
				else
					@sendErrorNotFound(res)
			)
			return
		)
		return

	sendClient: (uri, res) ->
		fs.readFile(@clientFilePaths[uri], (err, data) =>
			if(err)
				@sendErrorInternal(res)
				return
			res.writeHead(200, {'Content-Type': @clientContentTypes[uri]})
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
				isDir = fs.statSync(path.join(realPath, files[i])).isDirectory()
				if(isDir)
					uriStart = realPath.replace(@publicDir, '/dir')
				else
					uriStart = realPath.replace(@publicDir, '/file')
				uri = path.join(uriStart, files[i])
				dataToSend[i] = {
					name: files[i]
					uri: uri
					isDir: isDir
				}
			res.writeHead(200, {'Content-Type': 'application/json'})
			res.write(JSON.stringify(dataToSend))
			res.end()
		)
		return
	sendFile: (filepath, res) ->
		console.log "Sending #{filepath}"
		stream = fs.createReadStream(filepath)
		res.writeHead(200)
		stream.pipe(res, {end:true})
		return
	sendErrorNotFound: (res) ->
		res.writeHead(404)
		res.end()
	sendErrorInternal: (res) ->
		res.writeHead(500)
		res.end()

dir = process.cwd()
port = 4567
fileServer = new FileServer(port, dir)
fileServer.startServer()
