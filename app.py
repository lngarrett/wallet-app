from flask import Flask
import requests
import json
import os

app = Flask(__name__)

@app.route('/')
def health():
    return("Healthy!")

@app.route('/wallet/balance/<address>')
def balance(address):

    url = f"https://mainnet.infura.io/v3/{os.environ['API_KEY']}"
    myobj = {"jsonrpc":"2.0","method":"eth_getBalance","params": [address, "latest"],"id":1}
    x = requests.post(url, json = myobj)
    balance = str(float.fromhex(json.loads(x.text)['result'])/1000000000000000000) # wei to eth conversion
    return json.dumps({'balance': balance})
        
    
    