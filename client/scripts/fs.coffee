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
			@$el.html("<img src=\"img/file.png\"><a href=\"#{@model.get('uri')}\" class=\"filename\">#{@model.get('name')}</a><br /><span class=\"filesize\">#{@model.get('size')}<span>")
		return @
)
#class FV.FileMainView extends Backbone.View
FV.FileMainView = Backbone.View.extend(
	el: $('#main')
	initialize: ->
		FV.fileList = new FV.FileList()
		FV.path = '/'
		@pathHeader = @$('#current_path')
		@list = @$('#file_list')
		@listenTo(FV.fileList, 'reset', @render)
		@dirAjaxHandler('/dir/')
		return

	dirAjaxHandler: (uri) ->
		$.ajax({
			url: uri
			type: 'GET'
			dataType: 'json'
			success: (data) =>
				@updatePathAndFiles(data, uri)
		})
		return

	updatePathAndFiles: (data, path) ->
		newItems = []
		for file in data
			item = new FV.FileItem(file)
			newItems.push(item)
		FV.fileList.reset(newItems)
		FV.path = path
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

