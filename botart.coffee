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
qs     = require 'querystring'
env    = process.env


#
# robot brain
#

username = env.BOTART_USERNAME
password = env.BOTART_PASSWORD

client  = http.createClient(443, 'convore.com', true)
auth    = 'Basic ' + new Buffer(username + ':' + password).toString('base64')
request = (method, path, body, callback) ->
  headers =
    Authorization  : auth
    Host           : 'convore.com'
    'Content-Type' : 'application/json'

  if typeof(body) is 'function' and not callback
    callback = body
    body = null

  if method is 'POST' and body
    body = JSON.stringify(body) if typeof(body) isnt 'string'
    headers['Content-Length'] = body.length

  request = client.request(method, path, headers)

  request.on 'response', (response) ->
    if response.statusCode is 200
      data = ''
      response.setEncoding('utf8')
      response.on 'data', (chunk) ->
        data += chunk
      response.on 'end', ->
        callback(data)
    else
      console.log "#{response.statusCode}: #{path}"
      response.setEncoding('utf8')
      response.on 'data', (chunk) ->
        console.log chunk

  request.write(body) if method is 'POST' and body
  request.end()

post = (path, body, callback) ->
  request('POST', path, body, callback)

get = (path, body, callback) ->
  request('GET', path, body, callback)

handlers = []

hear = (pattern, callback) ->
  handlers.push [ pattern, callback ]

dispatch = (message) ->
  for pair in handlers
    [ pattern, handler ] = pair
    if pattern.test(message.message) then handler(message)

log = (message) ->
  console.log "#{message.topic.name} >> #{message.user.username}: #{message.message}"

say = (topic, message) ->
  data = qs.stringify { message: message }
  post "/api/topics/#{topic}/messages/create.json", data, (body) ->
    log JSON.stringify(body)

listen = ->
  get '/api/live.json', (body) ->
    for message in JSON.parse(body).messages
      if message.kind is 'message'
        dispatch(message) if /botart/.test(message.message)
        log message
    listen()


#
# robot heart
#

get '/api/account/verify.json', ->
  say 850, "Yes..."


#
# robot personality
#

hear /feeling/, (message) ->
  say(message.topic.id, "i can... speak")