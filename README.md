
## 🧪 non blocking U.I using python socket as a webserver.: 
### Don't use as it is! just a concept for maybe further work 
 (not a library, just for discussion with fellow mojicians)
#### potential solution for non-blocking interactions
- using Python.import_module("socket")
- provide some interactivity trough forms and links
- could use css with a little bit of work
- dynamic routes
- there is plenty of css frameworks
-  most web browsers support audio and video and images out of the box
- many people already knows a little bit of html

#### mojo provides super expressive powers, what are your favorites?

#### What do you think, would it make sense to use webserver as a gui?

#### does anybody knows how to make the web server less buggy

#### what are the disavantages of this way ?

#### anybody in the community worked on that? what are the impressions ?

# code need improvements:
> not ready for use! how to improve and what to change/keep?

```python
var message:StringLiteral = "hello world"
var input_value:Int = 0
var result:Int = 0

#low level performant code
fn do_mojo_work():
    result = input_value*input_value 

#higher level for abstraction (still in mojo, using PythonObject)
def page(inout req:Request) -> None:
    req += "<h1>🧪 unstable, don't use the code as is</h1>"
    req += "<h1>" + String(message) + "</h1>"

    if req.path == "/increment_input_value":
        input_value+=1
        do_mojo_work()
    
    if req.path == "/change_slider":
        input_value = atol(req.data_url["slider"].to_string())
        do_mojo_work()
        
    req += String("input_value: ")+input_value
    req += String("<br>result: ")+result
    req += "<br>path: " + req.path
    
    # /?page=123&id=1 => PythonObject({"page":123,"id":1})
    req += "<br>data: " + req.data_url.to_string()

    req += "<hr> <a href='/increment_input_value'> increment </a> <hr>"

    req += "<form action='/change_slider'>"
    req += "<input type='range' name='slider' min='0' max='10' "
    req += "value='" + String(input_value) + "'/>"
    req += "<br><input type='submit' value='Submit'>"
    req += "</form>"
    
    req += "<hr> <a href='/stop'> stop server </a>"

def main():
    var server = Request()

    var python_time = Python.import_module("time")    

    while True:
        #wont block if no request
        server.handle_one_request[page]()
        
        #set when visiting /stop
        if server.running == False:
            return

        #slow down the loop to +- 16 req/s
        python_time.sleep(1.0/16.0)
    
    server.stop()
```

```python
from python import Python
import time

@value
struct Request:
    var text:String
    var path:String
    var method:String
    var data_url: PythonObject
    var server_socket: PythonObject
    var running: Bool
    
    fn __init__(inout self,host:StringLiteral="127.0.0.1",port:Int=8000) raises:
        self.text = ""
        self.path = ""
        self.method = ""
        self.data_url = PythonObject()
        self.server_socket = PythonObject()
        
        var socket = Python.import_module("socket")
        
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.bind((host, port))
        self.server_socket.setblocking(0)

        self.server_socket.listen(1)
        print("http://"+String(host)+":"+String(port))
        self.running = True
        
    fn __iadd__(inout self, text:String):
        self.text += text
    
    def stop(inout self):
        self.server_socket.close()
        self.running = False
    
    def handle_one_request[entry: fn(inout Request) raises->None](inout self):
        if self.running == False:
            return
        try:
            var client = self.server_socket.accept()

            self.text = ""
            self.path = ""
            self.data_url = Python.evaluate("{}")
            
            request = client[0].recv(1024).decode()
            request_ = request.split('\n')[0].split(" ")
            
            self.method = request_[0].to_string()
            self.path = request_[1].split("?")[0].to_string()
            if self.path == "/stop":
                client[0].sendall(PythonObject('HTTP/1.0 200 OK\n\nStop server').encode())
                client[0].close()
                self.stop()
                return
            
            # /?page=123&id=1 => PythonObject({'page':'123','id':'1'})
            if request_[1].__len__() >=2:
                if request_[1].find("?") != -1:
                    var data = PythonObject(request_[1].split("?")[1].to_string())
                    var data_ = data.split("&")
                    for i in range(data_.__len__()):
                        var tmp = data_[i].split("=")
                        self.data_url.__setitem__(tmp[0],tmp[1])
            
            #should probably be a String and convert it later:
            response = PythonObject('HTTP/1.0 200 OK\n\n')
            response += "<!DOCTYPE html><html><head>"
            response += "<meta charset='utf-8'>"
            #to not get requests for favicon.ico, an empty one is used
            response += "<link rel='icon' href='data:;base64,='></head><body>"
            entry(self)
            response+= self.text
            response += "</body></html>"
                            
            client[0].sendall(response.encode())
            client[0].close()
            return
            
        except:
            return
```
