#
# Hello, and welcome to Botart.
#


#
# robot libraries
#

sys    = require 'sys'
path   = require 'path'
print  = sys.print
puts   = sys.puts
http   = require 'http'
env    = process.env


#
# robot brain
#

username = env.BOTART_USERNAME
password = env.BOTART_PASSWORD

auth  = 'Basic ' + new Buffer(username + ':' + password).toString('base64')
heads = {'host': 'convore.com', 'Authorization': auth}

client = http.createClient(443, 'convore.com', true)

handlers = {}

hear = (pattern, callback) ->
  handlers[pattern] = callback

dispatch = (message) ->
  for pattern, handler of handlers
    if pattern.test(message.message) then handler(message)

log = (data) ->
  for message in data.messages
    if message.kind is 'message'
      dispatch(message) if /botart/.test(message.message)
      console.log "#{message.topic.name} >> #{message.user.username}: #{message.message}"

listen = ->
  request = client.request('GET', '/api/live.json', heads)
  request.end()
  request.on 'response', (response) ->
    data = ''
    response.setEncoding('utf8')
    response.on 'data', (chunk) ->
      data += chunk
    response.on 'end', ->
      log JSON.parse(data)
      listen()

request = client.request('GET', '/api/account/verify.json', heads)
request.end()
request.on 'response', (response) ->
  if response.statusCode is 200
    listen()
  else
    console.log response.statusCode
    response.setEncoding('utf8')
    response.on 'data', (chunk) ->
      console.log chunk



#
# robot personality
#

hear /sup/, ->
  puts("yo!")