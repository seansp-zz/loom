from flask import Flask
from redis import Redis

app = Flask(__name__)
redis = Redis(host='redis', port=6379)

@app.route('/')
def hello():
  return '<a href="http://azureusage.westus2.cloudapp.azure.com:8080/job/treemap-locations-resourcegroups/ws/location-resourcegroup.treemap.html">TreeMap</a>\n<a href="http://azureusage.westus2.cloudapp.azure.com:8080/job/WordTree/ws/wordtree.html">WordTree</a>\n'

if __name__ == "__main__":
  app.run(host="0.0.0.0", debug=True)
