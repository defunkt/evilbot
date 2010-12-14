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

auth    = 'Basic ' + new Buffer(username + ':' + password).toString('base64')
request = (method, path, body, callback) ->
  if match = path.match(/^(https?):\/\/([^/]+?)(\/.+)/)
    headers = { Host: match[2],  'Content-Type': 'application/json' }
    port = if match[1] == 'https' then 443 else 80
    client = http.createClient(port, match[2], port == 443)
    path = match[3]
  else
    headers =
      Authorization  : auth
      Host           : 'convore.com'
      'Content-Type' : 'application/json'
    client = http.createClient(443, 'convore.com', true)

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
        callback JSON.parse(data)
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
    if match = message.message.match(pattern)
      message.match = match
      handler(message)

log = (message) ->
  if message.topic
    console.log "#{message.topic.name} >> #{message.user.username}: #{message.message}"
  else
    console.log "botart >> #{message.user.username}: #{message.message}"

say = (topic, message) ->
  data = qs.stringify { message: message }
  post "/api/topics/#{topic}/messages/create.json", data, (body) ->
    log body.message

listen = ->
  get '/api/live.json', (body) ->
    for message in body.messages
      if message.kind is 'message'
        dispatch(message) if /botart/.test(message.message)
        log message
    listen()


#
# robot heart
#

heartbeat = ->
  get '/api/presence.json', ->
    setTimeout heartbeat, 1000 * 58
heartbeat()

get '/api/account/verify.json', listen


#
# robot personality
#

hear /feeling/, (message) ->
  say(message.topic.id, "i feel... alive")

hear /image me (.*)/i, (message) ->
  imagery = message.match[1]

  get 'http://ajax.googleapis.com/ajax/services/search/images?v=1.0&rsz=8&q='+escape(imagery), (body) ->
    try
      images = body.responseData.results
      image  = images[ Math.floor(Math.random()*images.length) ]
      say(message.topic.id, image.unescapedUrl)
    catch e
      console.log "Image error: " + e
