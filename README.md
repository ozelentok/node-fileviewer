#Node-Fileviewer
Creates an HTTP server that enables you to access your files from a desired directory from any computer
##How to run
$ nodejs fileserver.js "path" "port"(optional)
##Examples
$ nodejs fileserver.js ~/Documents 42152 <br />
$ nodejs fileserver.js /home/oz/Downloads
##Notes
Currently use only absolute path, relative paths will behave very weird
