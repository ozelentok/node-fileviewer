#autocompile
class App
	constructor: ->
		@$file_list = $('#file_list')
		@dirAjaxHandler('/dir/')

	dirAjaxHandler: (uri) ->
		$.ajax({
			url: uri
			type: 'GET'
			dataType: 'json'
			success: (data) =>
				@appendDirContents(data)
		})
	appendDirContents: (data) ->
		counter = 0
		@$file_list.empty()
		for file in data
			if (file.isDir)
				@appendDirToList(file, 'dir' + counter)
				counter += 1
			else
				@appendFileToList(file)

	appendFileToList: (fileData) ->
		@$file_list.append("<li><a href=\"#{fileData.uri}\">#{fileData.name}</a></li>")
	appendDirToList: (dirData, id) ->
		@$file_list.append("<li><span class=\"dirLink\" id=\"#{id}\">#{dirData.name}</span></li>")
		$("##{id}").click( =>
			@dirAjaxHandler(dirData.uri)
		)

$(document).ready( ->
	app = new App()
)

