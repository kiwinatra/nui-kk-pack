import http.server import socketserver

PORT = 8000 DIRECTORY= "."

class Handler(http.server.SimpleHTTPRequestHandler): def init(self, args, **kwargs): super().init(args, directory=DIRECTORY, **kwargs)

with socketserver.TCPServer(("", PORT), Handler) as httpd: print(f"Serving at port {PORT}") httpd.serve_forever()