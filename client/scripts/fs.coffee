#autocompile
FV = {}
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
#class FV.FileMainView extends Backbone.View
FV.FileMainView = Backbone.View.extend(
	el: $('#main')
	initialize: ->
		FV.fileList = new FV.FileList()
		@listenTo(FV.fileList, 'reset', @render)
		@pathHeader = @$('#current_path')
		@list = @$('#file_list')
		@dirAjaxHandler('/')
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
		for file in data
			item = new FV.FileItem(file)
			newItems.push(item)
		FV.path = path
		FV.fileList.reset(newItems)
		return

	render: ->
		@list.empty()
		@pathHeader.html(FV.path)
		FV.fileList.each( (item) =>
			view = new FV.FileView({model: item})
			elem = view.render().el
			if(item.get('isDir'))
				$(elem).click( =>
					@dirAjaxHandler(item.get('uri'))
				)
			@list.append(elem)
		)
		return @
)
$(document).ready( ->
	window.FV = FV
	app = new FV.FileMainView()
	return
)

