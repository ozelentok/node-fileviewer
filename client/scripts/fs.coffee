#autocompile
FV = {}
FV.Constants =
	BACKSPACE_KEY: 8

#class FV.FileItem extends Backbone.Model
FV.FileItem = Backbone.Model.extend(
	defaults: {
		name: 'File'
		uri: '/file/'
		isDir: false
		size: 1
	}
)
#class FV.FileList extends Backbone.Collection
FV.FileList = Backbone.Collection.extend(
	model: FV.FileItem
)
#class FV.FileView extends Backbone.View
FV.FileView = Backbone.View.extend(
	tagName: 'li'
	render: ->
		if (@model.get('isDir'))
			@$el.html("<img src=\"img/directory.png\"><a class=\"filename\">#{@model.get('name')}</span>")
		else
			readableSize = @humanSize(@model.get('size'))
			@$el.html("<img src=\"img/file.png\" /><a href=\"/file#{@model.get('uri')}\" class=\"filename\">#{@model.get('name')}</a><span class=\"filesize\">#{readableSize}</span>")
		return @
	humanSize: (size) ->
		types = ['Bytes', 'KB', 'MB']
		for type in types
			if(size < 1024)
				return "#{size.toFixed(1)} #{type}"
			else
				size /= 1024
		return "#{size.toFixed(1)} GB"
)

FV.FileUploadFormView = Backbone.View.extend(
	el: $('#uploadForm')

	setPath: (path) ->
		@$el.attr('action', path)
		return
)

#class FV.FileMainView extends Backbone.View
FV.FileMainView = Backbone.View.extend(
	el: $('#main')
	initialize: ->
		@fileList = new FV.FileList()
		@fileUploader = new FV.FileUploadFormView()
		@listenTo(@fileList, 'reset', @render)
		@pathHeader = @$('#current_path')
		@list = @$('#file_list')
		@dirAjaxHandler(window.location.pathname)
		return

	dirAjaxHandler: (path) ->
		$.ajax({
			url: '/dir' + path
			type: 'GET'
			dataType: 'json'
			success: (data) =>
				@updatePathAndFiles(data, path)
		})
		return

	updatePathAndFiles: (data, path) ->
		newItems = []
		if path isnt '/'
			newItems.push({
				name: 'Up to heigher directory'
				uri: @parentDir(path)
				isDir: true
				size: -1
			})
		for file in data
			item = new FV.FileItem(file)
			newItems.push(item)
		@path = path
		@fileList.reset(newItems)
		@fileUploader.setPath(path)
		return

	parentDir: (dirpath) ->
		for i in [dirpath.length - 2..0] by -1
			if dirpath[i] is '/'
				return dirpath.slice(0, i+1)
		return dirpath

	render: ->
		@list.empty()
		@pathHeader.html(@path)
		@fileList.each( (item) =>
			view = new FV.FileView({model: item})
			elem = view.render().el
			if(item.get('isDir'))
				uri = item.get('uri')
				$(elem).click( =>
					@dirAjaxHandler(uri)
				)
			@list.append(elem)
		)
		return @
)
$(document).ready( ->
	app = new FV.FileMainView()
	$('html').keyup((e) ->
		if e.keyCode is FV.Constants.BACKSPACE_KEY and app.path != '/'
			app.dirAjaxHandler(app.parentDir(app.path))
	)
	return
)

