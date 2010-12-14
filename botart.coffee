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

ua       = 'botart 1.0'
username = env.BOTART_USERNAME
password = env.BOTART_PASSWORD
auth     = 'Basic ' + new Buffer(username + ':' + password).toString('base64')

request = (method, path, body, callback) ->
  if match = path.match(/^(https?):\/\/([^/]+?)(\/.+)/)
    headers = { Host: match[2],  'Content-Type': 'application/json', 'User-Agent': ua }
    port = if match[1] == 'https' then 443 else 80
    client = http.createClient(port, match[2], port == 443)
    path = match[3]
  else
    headers =
      Authorization  : auth
      Host           : 'convore.com'
      'Content-Type' : 'application/json'
      'User-Agent'   : ua
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
        callback JSON.parse(data) if callback
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
      message.say = (thing) -> say(message.topic.id, thing)
      handler(message)

log = (message) ->
  console.log "#{message.topic.name} >> #{message.user.username}: #{message.message}"

say = (topic, message) ->
  post "/api/topics/#{topic}/messages/create.json", qs.stringify(message: message)

listen = ->
  get '/api/live.json', (body) ->
    for message in body.messages
      if message.kind is 'message'
        dispatch(message) if message.message.match(new RegExp(username))
        log message
    listen()


#
# robot heart
#

heartbeat = ->
  get '/api/presence.json', ->
    console.log 'beat beat...'
    setTimeout heartbeat, 30000
heartbeat()

get '/api/account/verify.json', listen


#
# robot personality
#

hear /feeling/, (message) ->
  message.say "i feel... alive"

hear /about/, (message) ->
  message.say "I am learning to love."

hear /wiki me (.*)/i, (message) ->
  term = escape(message.match[1])
  url  = "http://en.wikipedia.org/w/api.php?action=opensearch&search=#{term}&format=json"

  get url, (body) ->
    try
      if body[1][0]
        message.say "http://en.wikipedia.org/wiki/#{escape body[1][0]}"
      else
        message.say "nothin'"
    catch e
      console.log "Wiki error: " + e

hear /image me (.*)/i, (message) ->
  phrase = escape(message.match[1])
  url = "http://ajax.googleapis.com/ajax/services/search/images?v=1.0&rsz=8&q=#{phrase}"

  get url, (body) ->
    try
      images = body.responseData.results
      image  = images[ Math.floor(Math.random()*images.length) ]
      message.say image.unescapedUrl
    catch e
      console.log "Image error: " + e
