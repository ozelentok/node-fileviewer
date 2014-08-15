#Node-Fileviewer
Creates an HTTP server that enables you to access your files from a desired directory from any computer and upload to it
##How to run
```bash
$ node fileserver.js "path" "port"(optional)
```
##Examples
```bash
$ node fileserver.js ~/Documents 42152
```
```bash
$ node fileserver.js /home/oz/Downloads
```
##Notes
Currently use only absolute path, relative paths will behave very weird
