"""Client for the installed Blender MCP addon; isolated remaster worker on 9877."""
import socket, json, sys

def execute(code, port=9877):
    with socket.create_connection(('127.0.0.1', port), timeout=20) as s:
        s.settimeout(3600)
        s.sendall(json.dumps({'type':'execute','code':code,'strict_json':False}).encode()+b'\0')
        data=bytearray()
        while b'\0' not in data:
            chunk=s.recv(65536)
            if not chunk: break
            data.extend(chunk)
    result=json.loads(data.split(b'\0')[0])
    return result

if __name__=='__main__':
    code = open(sys.argv[1],encoding='utf-8-sig').read() if len(sys.argv)>1 else sys.stdin.read()
    print(json.dumps(execute(code),indent=2))
